#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    echo "Usage: $0 [all|minimal|ubuntu|arch|powershell]"
}

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi

case "${1:-all}" in
    all)
        SUITES=(minimal ubuntu arch powershell)
        ;;
    minimal|ubuntu|arch|powershell)
        SUITES=("$1")
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

for required_command in docker git; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "Required command not found: $required_command" >&2
        exit 1
    fi
done
GIT_BIN="$(command -v git)"

bash "$SCRIPT_DIR/check-script-coverage.sh"

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-docker-test.XXXXXX")"
STAGED_REPO="$STAGING_ROOT/repository"
BUILD_CACHE_BUST="${STAGING_ROOT##*/}-$$"

cleanup() {
    rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$STAGED_REPO"

# Copy only version-controlled and non-ignored working-tree files that are part
# of the install/test surface. This includes untracked work-in-progress files,
# while deliberately excluding the host .git directory and ignored local data.
while IFS= read -r -d '' relative_path; do
    source_path="$REPO_ROOT/$relative_path"
    destination_path="$STAGED_REPO/$relative_path"

    if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
        # `git ls-files --cached` also reports tracked files deleted in the
        # working tree. Their deletion must be reflected in the test snapshot.
        continue
    fi

    case "$relative_path" in
        home/*local-env.sh|home/*local-env.fish|home/*local-env.ps1)
            echo "Refusing to stage machine-local environment file: $relative_path" >&2
            exit 1
            ;;
        .chezmoiroot|home/*|tests/*|uninstall.sh|uninstall.ps1)
            ;;
        *)
            echo "Refusing to stage unexpected path: $relative_path" >&2
            exit 1
            ;;
    esac

    mkdir -p "$(dirname "$destination_path")"
    # Do not preserve host ACLs, extended attributes, ownership, or timestamps.
    # Git records the file content, symlink target, and executable bit needed by
    # the fixture without carrying that extra workstation metadata into Docker.
    COPYFILE_DISABLE=1 cp -P "$source_path" "$destination_path"
done < <(
    git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard -- \
        .chezmoiroot home tests uninstall.sh uninstall.ps1
)

required_paths=(.chezmoiroot home)
for suite in "${SUITES[@]}"; do
    case "$suite" in
        minimal)
            required_paths+=(
                tests/Dockerfile.minimal
                tests/container-test.sh
                tests/lib/testlib.sh
                uninstall.sh
            )
            ;;
        ubuntu)
            required_paths+=(
                tests/Dockerfile
                tests/container-test.sh
                tests/lib/testlib.sh
                uninstall.sh
            )
            ;;
        arch)
            required_paths+=(
                tests/Dockerfile.arch
                tests/container-test.sh
                tests/lib/testlib.sh
                uninstall.sh
            )
            ;;
        powershell)
            required_paths+=(
                tests/Dockerfile.powershell
                tests/powershell-test.ps1
                uninstall.ps1
            )
            ;;
    esac
done

for required_path in "${required_paths[@]}"; do
    if [ ! -e "$STAGED_REPO/$required_path" ]; then
        echo "Test snapshot is missing required path: $required_path" >&2
        exit 1
    fi
done

if [ -e "$STAGED_REPO/.git" ]; then
    echo 'The host .git directory was unexpectedly copied into the test snapshot.' >&2
    exit 1
fi

# Chezmoi's documented init path expects a repository. Create a fresh local
# repository using isolated Git configuration so no host hooks, signing setup,
# credential helpers, identity variables, or other settings enter the fixture.
fixture_git() {
    env -i \
        PATH='/usr/bin:/bin:/usr/sbin:/sbin' \
        LC_ALL=C \
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_AUTHOR_NAME='Dotfiles Docker Test' \
        GIT_AUTHOR_EMAIL='dotfiles-test@invalid.example' \
        GIT_COMMITTER_NAME='Dotfiles Docker Test' \
        GIT_COMMITTER_EMAIL='dotfiles-test@invalid.example' \
        "$GIT_BIN" "$@"
}

fixture_git -C "$STAGED_REPO" -c init.defaultBranch=main init --quiet
fixture_git -C "$STAGED_REPO" -c core.hooksPath=/dev/null add --all
fixture_git -C "$STAGED_REPO" \
        -c core.hooksPath=/dev/null \
        -c commit.gpgsign=false \
        commit --quiet --no-verify -m 'Create isolated Docker test fixture'

run_suite() {
    local suite="$1"
    local dockerfile
    local image="dotfiles-test-$suite"
    local distro
    local mode
    local -a platform_args=()
    local -a run_environment=()
    local -a test_command=()
    local -a build_args=(build --pull)
    local -a run_args=(run --rm)

    case "$suite" in
        minimal)
            dockerfile="$STAGED_REPO/tests/Dockerfile.minimal"
            distro='ubuntu'
            mode='minimal'
            run_environment=(
                -e "TEST_DISTRO=$distro"
                -e "TEST_MODE=$mode"
            )
            test_command=(bash /dotfiles/tests/container-test.sh)
            ;;
        ubuntu)
            dockerfile="$STAGED_REPO/tests/Dockerfile"
            distro='ubuntu'
            mode='optional'
            run_environment=(
                -e "TEST_DISTRO=$distro"
                -e "TEST_MODE=$mode"
            )
            test_command=(bash /dotfiles/tests/container-test.sh)
            ;;
        arch)
            dockerfile="$STAGED_REPO/tests/Dockerfile.arch"
            distro='arch'
            mode='optional'
            platform_args=(--platform linux/amd64)
            run_environment=(
                -e "TEST_DISTRO=$distro"
                -e "TEST_MODE=$mode"
            )
            test_command=(bash /dotfiles/tests/container-test.sh)
            ;;
        powershell)
            dockerfile="$STAGED_REPO/tests/Dockerfile.powershell"
            platform_args=(--platform linux/amd64)
            test_command=(
                pwsh -NoLogo -NoProfile
                -File /dotfiles/tests/powershell-test.ps1
            )
            ;;
        *)
            echo "Internal error: unknown test suite $suite" >&2
            return 2
            ;;
    esac

    echo "Building $suite Docker image..."
    if [ "${#platform_args[@]}" -gt 0 ]; then
        build_args+=("${platform_args[@]}")
    fi
    build_args+=(
        --build-arg "CHEZMOI_INSTALLER_CACHE_BUST=$BUILD_CACHE_BUST"
        -f "$dockerfile"
        -t "$image"
        "$STAGED_REPO/tests"
    )
    docker "${build_args[@]}"

    echo
    echo "Running $suite Docker test..."
    echo
    if [ "${#platform_args[@]}" -gt 0 ]; then
        run_args+=("${platform_args[@]}")
    fi
    if [ "${#run_environment[@]}" -gt 0 ]; then
        run_args+=("${run_environment[@]}")
    fi
    run_args+=(
        --mount "type=bind,src=$STAGED_REPO,dst=/dotfiles,readonly"
        "$image"
    )
    run_args+=("${test_command[@]}")
    docker "${run_args[@]}"
}

for suite in "${SUITES[@]}"; do
    run_suite "$suite"
done

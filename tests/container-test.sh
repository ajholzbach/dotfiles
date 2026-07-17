#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="/dotfiles/tests"
source "$SCRIPT_ROOT/lib/testlib.sh"

TEST_MODE="${TEST_MODE:-optional}"
distro_id="$(. /etc/os-release && printf '%s' "$ID")"
system_path='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

if [ -n "${TEST_DISTRO:-}" ] && [ "$distro_id" != "$TEST_DISTRO" ]; then
    fail "Expected distro $TEST_DISTRO, found $distro_id"
    print_summary_and_exit
fi
ok "Running $TEST_MODE test on expected distro ($distro_id)"

log "Checking template edge cases and installer safety guards..."
for posix_template in \
        run_before_00-create-restore-point.sh.tmpl \
        run_before_11-install-antidote.sh.tmpl \
        run_before_12-install-starship.sh.tmpl \
        run_after_20-save-fish-theme.sh.tmpl; do
    for template_os in linux darwin; do
        rendered_script="$(mktemp)"
        if chezmoi execute-template \
                --override-data "{\"chezmoi\":{\"os\":\"$template_os\"}}" \
                --file "/dotfiles/home/.chezmoiscripts/$posix_template" \
                > "$rendered_script" && sh -n "$rendered_script"; then
            ok "$posix_template renders as valid $template_os shell"
        else
            fail "$posix_template is invalid when rendered for $template_os"
        fi
        rm -f "$rendered_script"
    done
done

for kube_case in '{}' '{"kube":null}' '{"kube":{}}'; do
    if chezmoi execute-template --override-data "$kube_case" \
            --file /dotfiles/home/dot_config/starship.toml.tmpl >/dev/null 2>&1; then
        ok "Starship template renders with kube data $kube_case"
    else
        fail "Starship template fails with kube data $kube_case"
    fi
done

populated_starship="$(chezmoi execute-template \
    --override-data '{"kube":{"starshipContexts":"[kubernetes.context_aliases]\nfixture = \"fixture\""}}' \
    --file /dotfiles/home/dot_config/starship.toml.tmpl)"
if grep -Fq '[kubernetes.context_aliases]' <<< "$populated_starship"; then
    ok "Starship template renders populated kube context data"
else
    fail "Starship template dropped populated kube context data"
fi

starship_installer_test="$(mktemp)"
chezmoi execute-template --override-data '{"chezmoi":{"os":"linux"}}' \
    --file /dotfiles/home/.chezmoiscripts/run_before_12-install-starship.sh.tmpl \
    > "$starship_installer_test"

antidote_installer_test="$(mktemp)"
chezmoi execute-template --override-data '{"chezmoi":{"os":"linux"}}' \
    --file /dotfiles/home/.chezmoiscripts/run_before_11-install-antidote.sh.tmpl \
    > "$antidote_installer_test"

fish_theme_installer_test="$(mktemp)"
chezmoi execute-template --override-data '{"chezmoi":{"os":"linux"}}' \
    --file /dotfiles/home/.chezmoiscripts/run_after_20-save-fish-theme.sh.tmpl \
    > "$fish_theme_installer_test"

if grep -Fq 'INSTALLER_URL="https://starship.rs/install.sh"' \
        "$starship_installer_test" && \
        ! grep -Fq 'STARSHIP_VERSION=' "$starship_installer_test" && \
        ! grep -Fq 'INSTALLER_SHA256=' "$starship_installer_test" && \
        grep -Fq 'sh "$installer" --yes --bin-dir "$INSTALL_DIR"' \
            "$starship_installer_test"; then
    ok "Starship installer uses the unconstrained official latest-stable path"
else
    fail "Starship installer is pinned or does not use the official install endpoint"
fi

if grep -Fq 'ANTIDOTE_URL="https://github.com/mattmc3/antidote.git"' \
        "$antidote_installer_test" && \
        grep -Fq 'git clone --depth=1 "$ANTIDOTE_URL" "$staging"' \
            "$antidote_installer_test" && \
        ! grep -Eq 'ANTIDOTE_(VERSION|TAG)=' "$antidote_installer_test"; then
    ok "Antidote installer clones the unconstrained latest official checkout"
else
    fail "Antidote installer is pinned or does not use the official repository"
fi

installer_fixture="$(mktemp -d)"
mkdir -p "$installer_fixture/broken-bin" "$installer_fixture/broken-home"
printf '%s\n' '#!/usr/bin/env sh' 'exit 9' > "$installer_fixture/broken-bin/starship"
chmod +x "$installer_fixture/broken-bin/starship"
if env HOME="$installer_fixture/broken-home" \
        XDG_STATE_HOME="$installer_fixture/broken-state" \
        PATH="$installer_fixture/broken-bin:$system_path" \
        sh "$starship_installer_test" >/dev/null 2>&1; then
    fail "Starship installer accepted a broken command already on PATH"
else
    ok "Starship installer rejects a broken command already on PATH"
fi

mkdir -p "$installer_fixture/invalid-bin" "$installer_fixture/invalid-home"
printf '%s\n' '#!/usr/bin/env sh' 'printf "%s\n" "not-starship"' \
    > "$installer_fixture/invalid-bin/starship"
chmod +x "$installer_fixture/invalid-bin/starship"
if env HOME="$installer_fixture/invalid-home" \
        XDG_STATE_HOME="$installer_fixture/invalid-state" \
        PATH="$installer_fixture/invalid-bin:$system_path" \
        sh "$starship_installer_test" >/dev/null 2>&1; then
    fail "Starship installer accepted malformed version output"
else
    ok "Starship installer rejects malformed version output"
fi

mkdir -p "$installer_fixture/preserved-home/.local/bin"
printf '%s\n' '#!/usr/bin/env sh' 'printf "%s\n" "starship 9.9.9"' \
    > "$installer_fixture/preserved-home/.local/bin/starship"
chmod +x "$installer_fixture/preserved-home/.local/bin/starship"
preserved_starship_sha="$(sha256sum \
    "$installer_fixture/preserved-home/.local/bin/starship" | awk '{print $1}')"
if env HOME="$installer_fixture/preserved-home" \
        XDG_STATE_HOME="$installer_fixture/preserved-state" \
        PATH="$system_path" sh "$starship_installer_test" >/dev/null 2>&1 && \
        [ "$preserved_starship_sha" = "$(sha256sum \
            "$installer_fixture/preserved-home/.local/bin/starship" | awk '{print $1}')" ] && \
        [ ! -e "$installer_fixture/preserved-state/dotfiles/starship-installed-by-dotfiles" ]; then
    ok "Starship installer preserves an unlisted user-owned installation"
else
    fail "Starship installer overwrote or claimed a user-owned installation"
fi

invalid_marker_home="$installer_fixture/invalid-marker-home"
invalid_marker_state="$installer_fixture/invalid-marker-state"
invalid_backup_id='invalid-marker-fixture'
invalid_backup="$invalid_marker_state/dotfiles/backups/$invalid_backup_id"
mkdir -p "$invalid_marker_home/.local/bin" "$invalid_backup/files"
printf '%s\n' '#!/usr/bin/env sh' 'exit 0' \
    > "$invalid_marker_home/.local/bin/starship"
chmod +x "$invalid_marker_home/.local/bin/starship"
printf '%s\n' 'managed fixture' > "$invalid_marker_home/.invalid-marker-managed"
printf '%s\n' '.invalid-marker-managed' > "$invalid_backup/managed-files.txt"
: > "$invalid_backup/existing-files.txt"
printf '%s\n' "$invalid_backup_id" > "$invalid_marker_state/dotfiles/current-backup"
# A path-only marker is deliberately incomplete and must never authorize
# deletion of a binary.
printf '%s\n' "$invalid_marker_home/.local/bin/starship" \
    > "$invalid_marker_state/dotfiles/starship-installed-by-dotfiles"
if env HOME="$invalid_marker_home" XDG_STATE_HOME="$invalid_marker_state" \
        PATH="$PATH" sh /dotfiles/uninstall.sh --yes --keep-chezmoi \
        >/dev/null 2>&1 && \
        [ -x "$invalid_marker_home/.local/bin/starship" ]; then
    ok "Uninstall preserves Starship when its ownership marker is incomplete"
else
    fail "Uninstall trusted an incomplete Starship ownership marker"
fi

if [ "$TEST_MODE" != "minimal" ]; then
    user_antidote_home="$installer_fixture/user-antidote-home"
    user_antidote_state="$installer_fixture/user-antidote-state"
    mkdir -p "$user_antidote_home/.antidote"
    printf '%s\n' 'antidote() { :; }' \
        > "$user_antidote_home/.antidote/antidote.zsh"
    user_antidote_sha="$(sha256sum \
        "$user_antidote_home/.antidote/antidote.zsh" | awk '{print $1}')"
    if env HOME="$user_antidote_home" XDG_STATE_HOME="$user_antidote_state" \
            PATH="$system_path" sh "$antidote_installer_test" >/dev/null 2>&1 && \
            [ "$user_antidote_sha" = "$(sha256sum \
                "$user_antidote_home/.antidote/antidote.zsh" | awk '{print $1}')" ] && \
            [ ! -e "$user_antidote_state/dotfiles/antidote-installed-by-dotfiles" ]; then
        ok "Antidote installer preserves a valid user-owned installation"
    else
        fail "Antidote installer overwrote or claimed a user-owned installation"
    fi

    no_git_bin="$installer_fixture/no-git-bin"
    mkdir -p "$no_git_bin"
    ln -s "$(command -v zsh)" "$no_git_bin/zsh"
    if env HOME="$user_antidote_home" XDG_STATE_HOME="$user_antidote_state" \
            PATH="$no_git_bin" /bin/sh "$antidote_installer_test" \
            >/dev/null 2>&1; then
        ok "A valid user-owned Antidote installation does not require Git"
    else
        fail "Antidote installer required Git for a user-owned installation"
    fi

    no_git_home="$installer_fixture/no-git-home"
    mkdir -p "$no_git_home"
    if env HOME="$no_git_home" XDG_STATE_HOME="$installer_fixture/no-git-state" \
            PATH="$no_git_bin" /bin/sh "$antidote_installer_test" \
            >/dev/null 2>&1; then
        fail "Antidote installer silently skipped a fresh install without Git"
    elif [ ! -e "$no_git_home/.antidote" ] && \
            [ ! -e "$installer_fixture/no-git-state/dotfiles/antidote-installed-by-dotfiles" ]; then
        ok "Fresh Antidote installation fails safely when Git is unavailable"
    else
        fail "Antidote installer left partial state after a missing-Git failure"
    fi

    collision_home="$installer_fixture/antidote-collision-home"
    mkdir -p "$collision_home"
    if env HOME="$collision_home" \
            XDG_STATE_HOME="$installer_fixture/antidote-collision-state" \
            PATH="$system_path" /bin/sh -c '
                collision="$HOME/.antidote.tmp.$$"
                mkdir -p "$collision"
                printf "%s\n" preserve-me > "$collision/sentinel"
                . "$1"
            ' antidote-collision "$antidote_installer_test" >/dev/null 2>&1; then
        fail "Antidote installer accepted a colliding temporary path"
    elif collision_sentinel="$(find "$collision_home" \
            -path "$collision_home/.antidote.tmp.*/sentinel" \
            -type f -print -quit)" && \
            [ -n "$collision_sentinel" ] && \
            grep -Fqx 'preserve-me' "$collision_sentinel"; then
        ok "Antidote installer preserves a colliding temporary path"
    else
        fail "Antidote installer deleted a colliding temporary path"
    fi

    invalid_antidote_home="$installer_fixture/invalid-antidote-home"
    mkdir -p "$invalid_antidote_home/.antidote"
    printf '%s\n' '# does not define the Antidote function' \
        > "$invalid_antidote_home/.antidote/antidote.zsh"
    if env HOME="$invalid_antidote_home" \
            XDG_STATE_HOME="$installer_fixture/invalid-antidote-state" \
            PATH="$system_path" sh "$antidote_installer_test" >/dev/null 2>&1; then
        fail "Antidote installer accepted a non-working existing checkout"
    elif grep -Fq 'does not define the Antidote function' \
            "$invalid_antidote_home/.antidote/antidote.zsh"; then
        ok "Antidote installer rejects and preserves a non-working checkout"
    else
        fail "Antidote installer changed a non-working existing checkout"
    fi

    missing_theme_home="$installer_fixture/missing-theme-home"
    mkdir -p "$missing_theme_home"
    if env HOME="$missing_theme_home" \
            XDG_STATE_HOME="$installer_fixture/missing-theme-state" \
            PATH="$system_path" sh "$fish_theme_installer_test" >/dev/null 2>&1; then
        fail "Fish theme script accepted a missing managed theme"
    elif [ ! -e "$installer_fixture/missing-theme-state/dotfiles/fish-theme-applied-by-dotfiles" ]; then
        ok "Fish theme script fails safely when its managed theme is missing"
    else
        fail "Fish theme script recorded ownership after a failed save"
    fi
fi
rm -rf "$installer_fixture" "$starship_installer_test" \
    "$antidote_installer_test" "$fish_theme_installer_test"

log "Preparing pre-install fixtures..."
custom_xdg="$HOME/custom-xdg"
mkdir -p "$HOME/.config/git"
printf '%s\n' '# original bashrc' 'export ORIGINAL_BASHRC=1' > "$HOME/.bashrc"
printf '%s\n' '# original profile' 'export ORIGINAL_PROFILE=1' > "$HOME/.profile"
printf '%s\n' '# original global ignore' > "$HOME/.config/git/ignore"
chmod 0640 "$HOME/.bashrc"
chmod 0600 "$HOME/.profile"
ln -snf .bashrc "$HOME/.zprofile"

if [ "$TEST_MODE" != "minimal" ]; then
    XDG_CONFIG_HOME="$HOME/.config" fish -c '
        set -U fish_color_command 13579b
        set -eU fish_color_param
        set -U fish_color_custom_extra original-extra
        set -U dotfiles_theme_sentinel keep-me
        exit 0
    '
    frozen_fish_theme="$HOME/.config/fish/conf.d/fish_frozen_theme.fish"
    mkdir -p "$(dirname "$frozen_fish_theme")"
    printf '%s\n' \
        '# This file was created by fish when upgrading to version 4.3, to migrate' \
        '# a pre-existing universal theme to global variables.' \
        'set --global fish_color_command badbad' \
        'set --global fish_color_autosuggestion aaaaaa' \
        > "$frozen_fish_theme"
    chmod 0640 "$frozen_fish_theme"
    original_frozen_fish_sha="$(sha256sum "$frozen_fish_theme" | awk '{print $1}')"
    original_frozen_fish_mode="$(stat -c '%a' "$frozen_fish_theme")"
fi

original_bash_sha="$(sha256sum "$HOME/.bashrc" | awk '{print $1}')"
original_profile_sha="$(sha256sum "$HOME/.profile" | awk '{print $1}')"
original_ignore_sha="$(sha256sum "$HOME/.config/git/ignore" | awk '{print $1}')"
original_bash_mode="$(stat -c '%a' "$HOME/.bashrc")"
original_profile_mode="$(stat -c '%a' "$HOME/.profile")"
original_ignore_mode="$(stat -c '%a' "$HOME/.config/git/ignore")"

log "Running the documented init-and-apply path..."
apply_output=''
chezmoi_executable="$(command -v chezmoi)"
if env PATH="$system_path" sh -c 'command -v chezmoi' >/dev/null 2>&1; then
    fail "Bootstrap regression PATH unexpectedly contains chezmoi"
else
    ok "Bootstrap regression PATH excludes the freshly installed chezmoi"
fi
if apply_output="$(env PATH="$system_path" "$chezmoi_executable" \
        --use-builtin-git=true init --apply file:///dotfiles 2>&1)"; then
    apply_status=0
else
    apply_status=$?
fi

if [ "$apply_status" -ne 0 ]; then
    echo "$apply_output"
    fail "chezmoi init --apply failed (exit $apply_status)"
    print_summary_and_exit
fi
ok "chezmoi init --apply succeeded with its install directory absent from PATH"

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
assert_nonempty_file "$state_root/current-backup" \
    "Pre-install restore point recorded" \
    "Pre-install restore point missing"

backup_id="$(sed -n '1p' "$state_root/current-backup")"
backup_dir="$state_root/backups/$backup_id"
for original_path in .bashrc .profile .zprofile .config/git/ignore; do
    if grep -Fqx -e "$original_path" "$backup_dir/existing-files.txt"; then
        ok "Restore manifest captured $original_path"
    else
        fail "Restore manifest missed $original_path"
    fi
done

assert_nonempty_file "$HOME/.config/starship.toml" \
    "Starship configuration installed" \
    "Starship configuration missing"

assert_absent "$HOME/.config/cmux/settings.json" \
    "macOS-only cmux settings excluded on Linux" \
    "macOS-only cmux settings were installed on Linux"

if command -v starship >/dev/null 2>&1 && \
        starship --version | grep -Eq '^starship [0-9]+\.[0-9]+\.[0-9]+([[:space:]]|$)'; then
    ok "Latest stable Starship installed"
else
    fail "Latest stable Starship installation missing or invalid"
fi

assert_nonempty_file "$state_root/starship-installed-by-dotfiles" \
    "Starship ownership marker recorded" \
    "Starship ownership marker missing"

starship_marker_path="$(sed -n '1p' "$state_root/starship-installed-by-dotfiles")"
starship_marker_sha="$(sed -n '2p' "$state_root/starship-installed-by-dotfiles")"
if [ "$starship_marker_path" = "$HOME/.local/bin/starship" ] && \
        [ -n "$starship_marker_sha" ] && \
        [ "$starship_marker_sha" = "$(sha256sum "$starship_marker_path" | awk '{print $1}')" ]; then
    ok "Starship ownership marker identifies the installed binary"
else
    fail "Starship ownership marker is incomplete or stale"
fi

assert_nonempty_file "$HOME/.config/powershell/profile.ps1" \
    "Shared PowerShell profile installed" \
    "Shared PowerShell profile missing"

if grep -Fq 'starship init powershell' "$HOME/.config/powershell/profile.ps1"; then
    ok "PowerShell profile initializes Starship"
else
    fail "PowerShell profile does not initialize Starship"
fi

if env -i HOME="$HOME" USER="${USER:-testuser}" PATH="$system_path" \
        XDG_CONFIG_HOME="$custom_xdg" bash -lc \
        'command -v starship >/dev/null &&
         test "$STARSHIP_CONFIG" = "$HOME/.config/starship.toml" &&
         test "$BAT_CONFIG_PATH" = "$HOME/.config/bat/config"' >/dev/null 2>&1; then
    ok "Bash login startup discovers Starship and fixed managed config paths"
else
    fail "Bash login startup cannot discover Starship or its managed config"
fi

if bash -ic 'exit' >/dev/null 2>&1; then
    ok "Bash interactive startup succeeds"
else
    fail "Bash interactive startup fails"
fi

if [ "$TEST_MODE" = "minimal" ]; then
    for optional_command in fish zsh xonsh mise bat zoxide fzf tmux vim; do
        if command -v "$optional_command" >/dev/null 2>&1; then
            fail "Minimal install unexpectedly includes $optional_command"
        else
            ok "Minimal install does not require or install $optional_command"
        fi
    done

    assert_absent "$HOME/.antidote" \
        "Minimal install skips Antidote when Zsh is absent" \
        "Minimal install created Antidote without Zsh"
    assert_absent "$state_root/antidote-installed-by-dotfiles" \
        "Minimal install records no Antidote ownership" \
        "Minimal install recorded unexpected Antidote ownership"
    assert_absent "$state_root/fish-theme-applied-by-dotfiles" \
        "Minimal install skips Fish theme persistence when Fish is absent" \
        "Minimal install recorded unexpected Fish theme ownership"
    assert_absent "$HOME/.config/fish/fish_variables" \
        "Minimal install creates no Fish universal-variable state" \
        "Minimal install created Fish universal-variable state"
else
    for covered_command in fzf zoxide; do
        if command -v "$covered_command" >/dev/null 2>&1; then
            ok "Optional $covered_command integration is available for startup coverage"
        else
            fail "Optional $covered_command integration is missing from the test image"
        fi
    done

    assert_nonempty_file "$HOME/.antidote/antidote.zsh" \
        "Latest Antidote checkout installed when Zsh is present" \
        "Automatic Antidote installation is missing"
    assert_nonempty_file "$state_root/antidote-installed-by-dotfiles" \
        "Antidote ownership marker recorded" \
        "Antidote ownership marker missing"

    antidote_marker_path="$(sed -n '1p' \
        "$state_root/antidote-installed-by-dotfiles")"
    antidote_marker_commit="$(sed -n '2p' \
        "$state_root/antidote-installed-by-dotfiles")"
    if [ "$antidote_marker_path" = "$HOME/.antidote" ] && \
            [ "$antidote_marker_commit" = "$(git -C "$HOME/.antidote" rev-parse HEAD)" ] && \
            [ "$(git -C "$HOME/.antidote" config --get remote.origin.url)" = \
                'https://github.com/mattmc3/antidote.git' ]; then
        ok "Antidote ownership marker identifies the official installed checkout"
    else
        fail "Antidote ownership marker is incomplete or stale"
    fi

    assert_nonempty_file "$state_root/fish-theme-applied-by-dotfiles" \
        "Managed Fish theme ownership marker recorded" \
        "Managed Fish theme ownership marker missing"
    assert_nonempty_file "$state_root/fish-theme-restore.fish" \
        "Pre-theme Fish color variables recorded for uninstall" \
        "Pre-theme Fish color restoration state missing"
    assert_nonempty_file "$state_root/fish-frozen-theme-restore.fish" \
        "Fish frozen-theme migration file recorded for uninstall" \
        "Fish frozen-theme restoration state missing"
    assert_absent "$frozen_fish_theme" \
        "Conflicting Fish frozen-theme migration file removed" \
        "Fish frozen-theme migration file still shadows the managed theme"

    if grep -Fq 'set -U -- fish_color_custom_extra original-extra' \
            "$state_root/fish-theme-restore.fish"; then
        ok "Fish rollback captures custom universal color variables"
    else
        fail "Fish rollback missed a custom universal color variable"
    fi

    if XDG_CONFIG_HOME="$HOME/.config" fish -c '
            set -qU fish_color_command
            and test "$fish_color_command" = 89b4fa
            and set -qU fish_color_autosuggestion
            and test "$fish_color_autosuggestion" = 6c7086
            and test "$dotfiles_theme_sentinel" = keep-me
        ' >/dev/null 2>&1; then
        ok "Catppuccin Mocha is persisted without changing unrelated Fish state"
    else
        fail "Catppuccin Mocha was not persisted as Fish universal variables"
    fi

    if zsh -n "$HOME/.zshrc" && \
            zsh -ic 'whence -w compdef >/dev/null' >/dev/null 2>&1; then
        ok "Zsh configuration parses, starts, and initializes completion"
    else
        fail "Zsh configuration failed"
    fi

    zsh_bundle="$HOME/.cache/antidote/zsh_plugins.zsh"
    if [ -s "$zsh_bundle" ] && \
            grep -Fq 'zsh-syntax-highlighting' "$zsh_bundle" && \
            grep -Fq 'zsh-autosuggestions' "$zsh_bundle"; then
        ok "Antidote generated syntax-highlighting and autosuggestion plugins"
    else
        fail "Antidote did not generate the configured Zsh plugin bundle"
    fi
    if zsh -ic '
            typeset -f _zsh_highlight >/dev/null &&
                typeset -f _zsh_autosuggest_start >/dev/null
        ' >/dev/null 2>&1; then
        ok "Zsh syntax highlighting and autosuggestions load at startup"
    else
        fail "Configured Zsh interaction plugins are not active after startup"
    fi
    assert_absent "$HOME/.zsh_plugins.zsh" \
        "Generated Zsh plugin bundle stays in the cache" \
        "Generated Zsh plugin bundle leaked into the home directory"

    if env -i HOME="$HOME" USER="${USER:-testuser}" PATH="$system_path" \
            XDG_CONFIG_HOME="$custom_xdg" zsh -lc \
            'command -v starship >/dev/null &&
             test "$STARSHIP_CONFIG" = "$HOME/.config/starship.toml" &&
             test "$BAT_CONFIG_PATH" = "$HOME/.config/bat/config"' >/dev/null 2>&1; then
        ok "Zsh login startup discovers Starship and fixed managed config paths"
    else
        fail "Zsh login startup cannot discover Starship or its managed config"
    fi

    if fish -n "$HOME/.config/fish/config.fish" && fish -ic 'exit' >/dev/null 2>&1; then
        ok "Fish configuration parses and starts without Fisher"
    else
        fail "Fish configuration failed"
    fi

    if fish -ic 'functions -q fisher_setup; and not functions -q fisher' >/dev/null 2>&1; then
        ok "Fish optional setup is available without auto-installing Fisher"
    else
        fail "Fish optional setup contract is incorrect"
    fi

    if fish -c 'test "$STARSHIP_CONFIG" = "$HOME/.config/starship.toml"; and test (string join : $BAT_CONFIG_PATH) = "$HOME/.config/bat/config"' \
            >/dev/null 2>&1; then
        ok "Fish uses the fixed managed Starship and bat config paths"
    else
        fail "Fish lost the fixed managed Starship or bat config path"
    fi

    if env XDG_CONFIG_HOME="$custom_xdg" fish -c \
            'source "$HOME/.config/fish/config.fish";
             test "$STARSHIP_CONFIG" = "$HOME/.config/starship.toml"' >/dev/null 2>&1; then
        ok "Fish config keeps managed Starship discoverable with custom XDG_CONFIG_HOME"
    else
        fail "Fish config loses managed Starship with custom XDG_CONFIG_HOME"
    fi

    if xonsh -i -c 'exit' >/dev/null 2>&1; then
        ok "Xonsh configuration starts"
    else
        fail "Xonsh configuration failed"
    fi

    if xonsh -i -c 'assert $STARSHIP_CONFIG == f"{$HOME}/.config/starship.toml"; assert len($BAT_CONFIG_PATH) == 1 and $BAT_CONFIG_PATH[0] == f"{$HOME}/.config/bat/config"; exit' \
            >/dev/null 2>&1; then
        ok "Xonsh uses the fixed managed Starship and bat config paths"
    else
        fail "Xonsh lost the fixed managed Starship or bat config path"
    fi

    if bat "$HOME/.bashrc" >/dev/null 2>&1; then
        ok "bat loads its managed configuration and vendored theme"
    else
        fail "bat cannot load its managed configuration or vendored theme"
    fi

    mise_mock_dir="$(mktemp -d)"
    printf '%s\n' \
        '#!/usr/bin/env sh' \
        'case "${2:-}" in' \
        '  bash|zsh) printf "%s\\n" "export DOTFILES_MISE_MOCK=1" ;;' \
        '  fish) printf "%s\\n" "set -gx DOTFILES_MISE_MOCK 1" ;;' \
        '  xonsh) printf "%s\\n" "\$DOTFILES_MISE_MOCK = '\''1'\''" ;;' \
        '  *) exit 2 ;;' \
        'esac' > "$mise_mock_dir/mise"
    chmod +x "$mise_mock_dir/mise"

    if PATH="$mise_mock_dir:$PATH" bash -ic \
            'test "$DOTFILES_MISE_MOCK" = 1' >/dev/null 2>&1 && \
            PATH="$mise_mock_dir:$PATH" zsh -ic \
            'test "$DOTFILES_MISE_MOCK" = 1' >/dev/null 2>&1 && \
            PATH="$mise_mock_dir:$PATH" fish -ic \
            'test "$DOTFILES_MISE_MOCK" = 1' >/dev/null 2>&1 && \
            PATH="$mise_mock_dir:$PATH" xonsh -i -c \
            'assert $DOTFILES_MISE_MOCK == "1"; exit' >/dev/null 2>&1; then
        ok "Optional mise activation branches work in Bash, Zsh, Fish, and Xonsh"
    else
        fail "An optional mise activation branch failed"
    fi
    rm -rf "$mise_mock_dir"

    if vim -Nu "$HOME/.vimrc" -n -es '+qall' >/dev/null 2>&1; then
        ok "Vim configuration loads"
    else
        fail "Vim configuration failed"
        vim -Nu "$HOME/.vimrc" -n -e -V1 '+qall' 2>&1 || true
    fi

    tmux_socket="dotfiles-test-$$"
    if tmux -L "$tmux_socket" -f "$HOME/.config/tmux/tmux.conf" start-server \; \
            show-options -g >/dev/null 2>&1; then
        ok "tmux configuration loads"
        tmux -L "$tmux_socket" kill-server >/dev/null 2>&1 || true
    else
        fail "tmux configuration failed"
    fi
fi

if [ "$TEST_MODE" != "minimal" ]; then
    antidote_commit_before_reapply="$(git -C "$HOME/.antidote" rev-parse HEAD)"
    antidote_marker_sha_before_reapply="$(sha256sum \
        "$state_root/antidote-installed-by-dotfiles" | awk '{print $1}')"
    fish_restore_sha_before_reapply="$(sha256sum \
        "$state_root/fish-theme-restore.fish" | awk '{print $1}')"
    fish_marker_sha_before_reapply="$(sha256sum \
        "$state_root/fish-theme-applied-by-dotfiles" | awk '{print $1}')"
    frozen_restore_sha_before_reapply="$(sha256sum \
        "$state_root/fish-frozen-theme-restore.fish" | awk '{print $1}')"
    XDG_CONFIG_HOME="$HOME/.config" fish -c '
        set -U fish_color_command abcdef
        exit 0
    '
fi

restore_id_before="$(sed -n '1p' "$state_root/current-backup")"
source_dir="$(chezmoi source-path)"
printf '%s\n' 'original later-managed file' > "$HOME/.rollback_reconcile_fixture"
chmod 0644 "$HOME/.rollback_reconcile_fixture"
original_reconcile_sha="$(sha256sum "$HOME/.rollback_reconcile_fixture" | awk '{print $1}')"
printf '%s\n' 'managed later file' > "$source_dir/dot_rollback_reconcile_fixture"

log "Running a full second apply with a newly managed path, including scripts..."
second_apply_output=''
if second_apply_output="$(chezmoi apply 2>&1)"; then
    ok "Full second chezmoi apply succeeded"
else
    fail "Full second chezmoi apply failed"
    echo "$second_apply_output"
fi
assert_equal "$restore_id_before" "$(sed -n '1p' "$state_root/current-backup")" \
    "Second apply preserved the original restore point" \
    "Second apply replaced the original restore point"

if [ "$TEST_MODE" != "minimal" ]; then
    if [ "$antidote_commit_before_reapply" = \
            "$(git -C "$HOME/.antidote" rev-parse HEAD)" ] && \
            [ "$antidote_marker_sha_before_reapply" = "$(sha256sum \
                "$state_root/antidote-installed-by-dotfiles" | awk '{print $1}')" ]; then
        ok "Second apply leaves the current Antidote checkout unchanged"
    else
        fail "Second apply changed Antidote or its ownership marker"
    fi

    if [ "$fish_restore_sha_before_reapply" = "$(sha256sum \
            "$state_root/fish-theme-restore.fish" | awk '{print $1}')" ] && \
            [ "$fish_marker_sha_before_reapply" = "$(sha256sum \
                "$state_root/fish-theme-applied-by-dotfiles" | awk '{print $1}')" ] && \
            [ "$frozen_restore_sha_before_reapply" = "$(sha256sum \
                "$state_root/fish-frozen-theme-restore.fish" | awk '{print $1}')" ] && \
            XDG_CONFIG_HOME="$HOME/.config" fish -c '
                test "$fish_color_command" = 89b4fa
                and test "$fish_color_autosuggestion" = 6c7086
            ' >/dev/null 2>&1; then
        ok "Second apply repairs Fish theme drift without replacing restore state"
    else
        fail "Second apply did not repair Fish theme drift safely"
    fi
fi

if grep -Fqx -e '.rollback_reconcile_fixture' "$backup_dir/managed-files.txt" && \
        grep -Fqx -e '.rollback_reconcile_fixture' "$backup_dir/existing-files.txt" && \
        [ "$original_reconcile_sha" = "$(sha256sum \
            "$backup_dir/files/.rollback_reconcile_fixture" | awk '{print $1}')" ]; then
    ok "Second apply captured the original for a newly managed path"
else
    fail "Second apply did not reconcile the newly managed path into the restore point"
fi
managed_diff=''
if managed_diff="$(chezmoi diff --exclude=scripts 2>&1)" && \
        [ -z "$managed_diff" ]; then
    ok "Managed-file diff is clean after the full scripted re-apply"
else
    fail "Managed-file diff is not clean after the full scripted re-apply"
    echo "$managed_diff"
fi

managed_bash_sha="$(sha256sum "$HOME/.bashrc" | awk '{print $1}')"
if sh /dotfiles/uninstall.sh --dry-run --yes >/dev/null 2>&1 && \
        [ "$managed_bash_sha" = "$(sha256sum "$HOME/.bashrc" | awk '{print $1}')" ]; then
    ok "Uninstall dry run makes no changes"
else
    fail "Uninstall dry run changed managed files"
fi

if [ "$TEST_MODE" != "minimal" ]; then
    broken_fish_bin="$(mktemp -d)"
    printf '%s\n' '#!/usr/bin/env sh' 'exit 127' > "$broken_fish_bin/fish"
    chmod +x "$broken_fish_bin/fish"
    if PATH="$broken_fish_bin:$PATH" \
            sh /dotfiles/uninstall.sh --yes >/dev/null 2>&1; then
        fail "Uninstall continued when Fish theme restoration was unavailable"
    elif [ "$managed_bash_sha" = "$(sha256sum "$HOME/.bashrc" | awk '{print $1}')" ] && \
            [ -s "$state_root/current-backup" ] && \
            [ -s "$state_root/fish-theme-applied-by-dotfiles" ] && \
            [ -s "$state_root/fish-theme-restore.fish" ] && \
            [ -d "$HOME/.local/share/chezmoi" ]; then
        ok "Uninstall stops safely when Fish theme restoration is unavailable"
    else
        fail "Failed Fish restoration consumed recoverable uninstall state"
    fi
    rm -rf "$broken_fish_bin"
fi

log "Restoring the pre-install state..."
uninstall_output=''
if uninstall_output="$(sh /dotfiles/uninstall.sh --yes 2>&1)"; then
    ok "Uninstall and restore completed"
else
    fail "Uninstall and restore failed"
    echo "$uninstall_output"
fi

assert_equal "$original_bash_sha" "$(sha256sum "$HOME/.bashrc" | awk '{print $1}')" \
    "Original .bashrc restored byte-for-byte" \
    "Original .bashrc was not restored"
assert_equal "$original_profile_sha" "$(sha256sum "$HOME/.profile" | awk '{print $1}')" \
    "Original .profile restored byte-for-byte" \
    "Original .profile was not restored"
assert_equal "$original_ignore_sha" "$(sha256sum "$HOME/.config/git/ignore" | awk '{print $1}')" \
    "Original Git ignore restored byte-for-byte" \
    "Original Git ignore was not restored"
assert_equal "$original_bash_mode" "$(stat -c '%a' "$HOME/.bashrc")" \
    "Original .bashrc mode restored" \
    "Original .bashrc mode changed"
assert_equal "$original_profile_mode" "$(stat -c '%a' "$HOME/.profile")" \
    "Original .profile mode restored" \
    "Original .profile mode changed"
assert_equal "$original_ignore_mode" "$(stat -c '%a' "$HOME/.config/git/ignore")" \
    "Original Git ignore mode restored" \
    "Original Git ignore mode changed"
assert_equal "$original_reconcile_sha" \
    "$(sha256sum "$HOME/.rollback_reconcile_fixture" | awk '{print $1}')" \
    "Original later-managed fixture restored" \
    "Later-managed fixture was not restored"

if [ -L "$HOME/.zprofile" ] && [ "$(readlink "$HOME/.zprofile")" = '.bashrc' ]; then
    ok "Original .zprofile symlink restored"
else
    fail "Original .zprofile symlink was not restored"
fi

assert_absent "$HOME/.zshrc" \
    "Newly managed .zshrc removed" \
    "Newly managed .zshrc remains"
assert_absent "$HOME/.local/bin/starship" \
    "Installer-owned Starship removed" \
    "Installer-owned Starship remains"
assert_absent "$state_root/starship-installed-by-dotfiles" \
    "Starship ownership marker removed" \
    "Starship ownership marker remains"
assert_absent "$HOME/.antidote" \
    "Installer-owned Antidote removed" \
    "Installer-owned Antidote remains"
assert_absent "$state_root/antidote-installed-by-dotfiles" \
    "Antidote ownership marker removed" \
    "Antidote ownership marker remains"
assert_absent "$state_root/fish-theme-applied-by-dotfiles" \
    "Fish theme ownership marker removed" \
    "Fish theme ownership marker remains"
assert_absent "$state_root/fish-theme-restore.fish" \
    "Fish theme restoration state consumed" \
    "Fish theme restoration state remains"
assert_absent "$state_root/fish-frozen-theme-restore.fish" \
    "Fish frozen-theme restoration state consumed" \
    "Fish frozen-theme restoration state remains"

if [ "$TEST_MODE" != "minimal" ]; then
    if XDG_CONFIG_HOME="$HOME/.config" fish -c '
            set -eg fish_color_command fish_color_param fish_color_custom_extra
            set -qU fish_color_command
            and test "$fish_color_command" = 13579b
            and not set -qU fish_color_param
            and test "$fish_color_custom_extra" = original-extra
            and test "$dotfiles_theme_sentinel" = keep-me
        ' >/dev/null 2>&1; then
        ok "Uninstall restored prior Fish colors and preserved unrelated state"
    else
        fail "Uninstall did not restore the pre-install Fish color state"
    fi

    if [ "$original_frozen_fish_sha" = \
            "$(sha256sum "$frozen_fish_theme" | awk '{print $1}')" ] && \
            [ "$original_frozen_fish_mode" = "$(stat -c '%a' "$frozen_fish_theme")" ]; then
        ok "Uninstall restored the prior Fish frozen-theme file exactly"
    else
        fail "Uninstall did not restore the prior Fish frozen-theme file"
    fi
fi
assert_absent "$state_root/current-backup" \
    "Consumed restore-point pointer cleared for a future install" \
    "Consumed restore-point pointer remains"
assert_absent "$HOME/.local/share/chezmoi" \
    "chezmoi source purged" \
    "chezmoi source remains after uninstall"
assert_nonempty_file "$state_root/last-uninstall-snapshot" \
    "Pre-uninstall recovery snapshot recorded" \
    "Pre-uninstall recovery snapshot missing"
assert_equal "$backup_id" "$(sed -n '1p' "$state_root/last-restored-backup")" \
    "Consumed restore-point identifier recorded" \
    "Consumed restore-point identifier was not recorded"

print_summary_and_exit

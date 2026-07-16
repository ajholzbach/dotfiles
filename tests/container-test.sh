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
        run_before_12-install-starship.sh.tmpl; do
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
rm -rf "$installer_fixture" "$starship_installer_test"

log "Preparing pre-install fixtures..."
custom_xdg="$HOME/custom-xdg"
mkdir -p "$HOME/.config/git"
printf '%s\n' '# original bashrc' 'export ORIGINAL_BASHRC=1' > "$HOME/.bashrc"
printf '%s\n' '# original profile' 'export ORIGINAL_PROFILE=1' > "$HOME/.profile"
printf '%s\n' '# original global ignore' > "$HOME/.config/git/ignore"
chmod 0640 "$HOME/.bashrc"
chmod 0600 "$HOME/.profile"
ln -snf .bashrc "$HOME/.zprofile"

original_bash_sha="$(sha256sum "$HOME/.bashrc" | awk '{print $1}')"
original_profile_sha="$(sha256sum "$HOME/.profile" | awk '{print $1}')"
original_ignore_sha="$(sha256sum "$HOME/.config/git/ignore" | awk '{print $1}')"
original_bash_mode="$(stat -c '%a' "$HOME/.bashrc")"
original_profile_mode="$(stat -c '%a' "$HOME/.profile")"
original_ignore_mode="$(stat -c '%a' "$HOME/.config/git/ignore")"

log "Running the documented init-and-apply path..."
apply_output=''
if apply_output="$(chezmoi --use-builtin-git=true init --apply file:///dotfiles 2>&1)"; then
    apply_status=0
else
    apply_status=$?
fi

if [ "$apply_status" -ne 0 ]; then
    echo "$apply_output"
    fail "chezmoi init --apply failed (exit $apply_status)"
    print_summary_and_exit
fi
ok "chezmoi init --apply succeeded"

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
else
    for covered_command in fzf zoxide; do
        if command -v "$covered_command" >/dev/null 2>&1; then
            ok "Optional $covered_command integration is available for startup coverage"
        else
            fail "Optional $covered_command integration is missing from the test image"
        fi
    done

    if zsh -n "$HOME/.zshrc" && zsh -ic 'exit' >/dev/null 2>&1; then
        ok "Zsh configuration parses and starts"
    else
        fail "Zsh configuration failed"
    fi

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

#!/usr/bin/env bash
set -euo pipefail

source /dotfiles/tests/lib/testlib.sh

TEST_MODE="${TEST_MODE:-optional}"
distro_id="$(. /etc/os-release && printf '%s' "$ID")"
system_path='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
scripts=/dotfiles/home/.chezmoiscripts

sha() { sha256sum "$1" | cut -d ' ' -f 1; }

# full_mode: succeed in the suites that install the optional shells and tools
full_mode() { [ "$TEST_MODE" != minimal ]; }

# render SCRIPT OS: print a chezmoi script template rendered for OS
render() {
    chezmoi execute-template --source /dotfiles/home \
        --override-data "{\"chezmoi\":{\"os\":\"$2\"},\"tools\":true}" \
        --file "$scripts/$1"
}

# restore_point_fixture DIR: create DIR/home with a one-file restore point
restore_point_fixture() {
    local state="$1/home/.local/state/dotfiles"
    mkdir -p "$state/backups/fixture/files"
    printf '%s\n' .fixture > "$state/backups/fixture/managed-files.txt"
    : > "$state/backups/fixture/existing-files.txt"
    printf '%s\n' fixture > "$state/current-backup"
}

# fixture_uninstall DIR [VAR=VALUE...]: run uninstall.sh in the DIR fixture
fixture_uninstall() {
    env HOME="$1/home" XDG_STATE_HOME="$1/home/.local/state" "${@:2}" \
        sh /dotfiles/uninstall.sh --yes --keep-chezmoi
}

if [ -n "${TEST_DISTRO:-}" ] && [ "$distro_id" != "$TEST_DISTRO" ]; then
    fail "Expected distro $TEST_DISTRO, found $distro_id"
    print_summary_and_exit
fi
ok "Running $TEST_MODE test on expected distro ($distro_id)"

log "Checking script templates..."
valid_shell() {
    local script
    script="$(render "$1" "$2")" && printf '%s\n' "$script" | sh -n
}
for template in "$scripts"/*.sh.tmpl; do
    for os in linux darwin; do
        check "${template##*/} renders as valid $os shell" valid_shell "${template##*/}" "$os"
    done
done

starship_template=/dotfiles/home/dot_config/starship.toml.tmpl
for kube in '{}' '{"kube":null}' '{"kube":{}}'; do
    check "Starship template renders with kube data $kube" \
        chezmoi execute-template --override-data "$kube" --file "$starship_template"
done
if chezmoi execute-template --file "$starship_template" \
        --override-data '{"kube":{"starshipContexts":"[kubernetes.context_aliases]\nfixture = \"fixture\""}}' |
        grep -Fq '[kubernetes.context_aliases]'; then
    ok "Starship template renders populated kube context data"
else
    fail "Starship template dropped populated kube context data"
fi

log "Checking the macOS font externals..."
# darwin_fonts: print the font targets that chezmoi installs on macOS
darwin_fonts() {
    chezmoi execute-template --source /dotfiles/home --override-data '{"chezmoi":{"os":"darwin"}}' \
        --file /dotfiles/home/.chezmoiexternal.toml.tmpl | sed -n 's/^\["\(.*\)"\]$/\1/p'
}
assert_equal "$(printf 'Library/Fonts/MesloLGSNerdFont-%s.ttf\n' Regular Bold Italic BoldItalic)" \
    "$(darwin_fonts)" \
    "macOS installs the four font files into ~/Library/Fonts" \
    "macOS font targets are wrong"

log "Checking that installers leave existing installations alone..."
fixture="$(mktemp -d)"
render run_after_12-install-starship.sh.tmpl linux > "$fixture/starship.sh"
render run_after_16-install-antidote.sh.tmpl linux > "$fixture/antidote.sh"
# The Antidote script needs only zsh
# Put only a zsh stub on PATH
stub "$fixture/bin" zsh 'exit 0'
run_installer() {
    env HOME="$2" XDG_STATE_HOME="$2/state" PATH="$fixture/bin" /bin/sh "$fixture/$1"
}
# keeps_existing SCRIPT HOME FILE MARKER: SCRIPT succeeds, FILE is unchanged,
# and no ownership MARKER is written.
keeps_existing() {
    local before
    before="$(sha "$2/$3")"
    run_installer "$1" "$2" && [ "$(sha "$2/$3")" = "$before" ] &&
        [ ! -e "$2/state/dotfiles/$4" ]
}
stub "$fixture/starship-home/.local/bin" starship 'echo starship 9.9.9'
check "Starship installer keeps an existing ~/.local/bin/starship" \
    keeps_existing starship.sh "$fixture/starship-home" .local/bin/starship starship-installed-by-dotfiles
mkdir -p "$fixture/antidote-home/.antidote"
printf '%s\n' 'antidote() { :; }' > "$fixture/antidote-home/.antidote/antidote.zsh"
check "Antidote installer keeps an existing ~/.antidote without needing Git" \
    keeps_existing antidote.sh "$fixture/antidote-home" .antidote/antidote.zsh antidote-installed-by-dotfiles
mkdir -p "$fixture/no-git-home"
fails_without_git() {
    ! run_installer antidote.sh "$1" && ! compgen -G "$1/.antidote*" &&
        [ ! -e "$1/state/dotfiles/antidote-installed-by-dotfiles" ]
}
check "Fresh Antidote install fails without Git and leaves no state" \
    fails_without_git "$fixture/no-git-home"

log "Checking that uninstall keeps tools changed after installation..."
restore_point_fixture "$fixture/changed"
changed_home="$fixture/changed/home"
changed_state="$changed_home/.local/state/dotfiles"
stub "$changed_home/.local/bin" starship 'echo installed'
sha "$changed_home/.local/bin/starship" > "$changed_state/starship-installed-by-dotfiles"
stub "$changed_home/.local/bin" starship 'echo changed by the user'
git init -q "$changed_home/.antidote"
git -C "$changed_home/.antidote" -c user.name=test -c user.email=test@invalid.example \
    commit -q --allow-empty -m fixture
git -C "$changed_home/.antidote" rev-parse HEAD > "$changed_state/antidote-installed-by-dotfiles"
touch "$changed_home/.antidote/user-file"
check "Uninstall succeeds with changed tools" fixture_uninstall "$fixture/changed"
check "Uninstall keeps a Starship binary changed after installation" \
    test -x "$changed_home/.local/bin/starship"
check "Uninstall keeps an Antidote checkout changed after installation" \
    test -e "$changed_home/.antidote/user-file"

rm -rf "$fixture"

log "Checking the RTK hook setup script..."
rtk_dir="$(mktemp -d)"
mkdir -p "$rtk_dir/.codex"
stub "$rtk_dir/bin" rtk \
    'printf "%s\n" "$*" >> "$HOME/rtk.log"' \
    'case "$*" in *--codex*) printf "\n@RTK.md\n" >> "$HOME/.codex/AGENTS.md" ;; esac' \
    'exit "${FAKE_RTK_STATUS:-0}"'
PATH="$rtk_dir/bin:$PATH" render run_onchange_after_30-init-rtk.sh.tmpl linux > "$rtk_dir/init-rtk.sh"
rtk_setup_ok() {
    printf '%s\n' '# managed rules' > "$rtk_dir/.codex/AGENTS.md"
    rm -f "$rtk_dir/rtk.log"
    FAKE_RTK_STATUS="$1" HOME="$rtk_dir" sh "$rtk_dir/init-rtk.sh" &&
        [ "$(cat "$rtk_dir/rtk.log")" = "$(printf '%s\n' 'init -g --auto-patch' 'init -g --codex')" ] &&
        [ "$(cat "$rtk_dir/.codex/AGENTS.md")" = '# managed rules' ]
}
for rtk_status in 0 1; do
    check "RTK setup exits 0 and keeps the managed AGENTS.md when rtk exits $rtk_status" \
        rtk_setup_ok "$rtk_status"
done
rm -rf "$rtk_dir"

log "Preparing pre-install fixtures..."
custom_xdg="$HOME/custom-xdg"
mkdir -p "$HOME/.config/git" "$HOME/.claude" "$HOME/.codex"
printf '%s\n' '# original bashrc' 'export ORIGINAL_BASHRC=1' > "$HOME/.bashrc"
printf '%s\n' '# original profile' 'export ORIGINAL_PROFILE=1' > "$HOME/.profile"
printf '%s\n' '# original global ignore' > "$HOME/.config/git/ignore"
printf '%s\n' '# original Claude rules' > "$HOME/.claude/CLAUDE.md"
printf '%s\n' '# original Codex rules' > "$HOME/.codex/AGENTS.md"
chmod 0640 "$HOME/.bashrc"
chmod 0600 "$HOME/.profile"
ln -snf .bashrc "$HOME/.zprofile"
# apply keeps the marked block and drops the unmarked line
# Write another tool's marked block and an unmarked line
bash_profile_block="$(printf '%s\n' '# >>> other tool >>>' 'export OTHER_TOOL=1' '# <<< other tool <<<')"
printf '%s\n' "$bash_profile_block" '# original bash_profile' > "$HOME/.bash_profile"

declare -A original_sha original_mode
# remember_original PATH: record the content and mode of ~/PATH
remember_original() {
    original_sha[$1]="$(sha "$HOME/$1")"
    original_mode[$1]="$(stat -c '%a' "$HOME/$1")"
}
for path in .bashrc .bash_profile .profile .config/git/ignore .claude/CLAUDE.md .codex/AGENTS.md; do
    remember_original "$path"
done

log "Running the documented init-and-apply path..."
chezmoi_executable="$(command -v chezmoi)"
if env PATH="$system_path" sh -c 'command -v chezmoi' >/dev/null 2>&1; then
    fail "Bootstrap regression PATH unexpectedly contains chezmoi"
else
    ok "Bootstrap regression PATH excludes the freshly installed chezmoi"
fi
if ! apply_output="$(env PATH="$system_path" "$chezmoi_executable" \
        --use-builtin-git=true init --apply --promptDefaults file:///dotfiles 2>&1)"; then
    echo "$apply_output"
    fail "chezmoi init --apply failed"
    print_summary_and_exit
fi
ok "chezmoi init --apply succeeded with its install directory absent from PATH"

# bash_profile_keeps_block: succeed when ~/.bash_profile is the kept block,
# a blank line, and then the managed file.
bash_profile_keeps_block() {
    [ "$(cat "$HOME/.bash_profile")" = "$bash_profile_block

$(chezmoi execute-template --source /dotfiles/home \
    --override-data '{"chezmoi":{"stdin":""}}' \
    --file /dotfiles/home/modify_dot_bash_profile)" ]
}
check "Apply keeps another tool's marked block in .bash_profile" bash_profile_keeps_block

assert_nonempty_file "$state_root/current-backup" \
    "Pre-install restore point recorded" \
    "Pre-install restore point missing"
backup_id="$(sed -n '1p' "$state_root/current-backup")"
backup_dir="$state_root/backups/$backup_id"
check "Apply reports the new restore point" \
    grep -Fqx "Created pre-install restore point: $backup_dir" <<< "$apply_output"
for path in .bashrc .profile .zprofile .config/git/ignore .codex/AGENTS.md; do
    if grep -Fqx -e "$path" "$backup_dir/existing-files.txt" &&
            { [ -e "$backup_dir/files/$path" ] || [ -L "$backup_dir/files/$path" ]; }; then
        ok "Restore point captured the original $path"
    else
        fail "Restore point missed the original $path"
    fi
done

assert_equal false "$(chezmoi execute-template '{{ .tools }}')" \
    "Default init installs only the dotfiles" \
    "Default init enabled the tools install"

font_files="$(chezmoi managed --include=files --path-style=relative | grep '^\.local/share/fonts/' || true)"
# every_font CHECK: succeed when CHECK passes for every managed font path
every_font() {
    local font
    [ -n "$font_files" ] || return 1
    while IFS= read -r font; do
        "$1" "$font" || return 1
    done <<< "$font_files"
}
font_installed() { [ -s "$HOME/$1" ] && grep -Fqx -e "$1" "$backup_dir/managed-files.txt"; }
font_removed() { [ ! -e "$HOME/$1" ]; }
check "Nerd Font files installed and recorded in the restore point" every_font font_installed

assert_nonempty_file "$HOME/.config/starship.toml" \
    "Starship configuration installed" \
    "Starship configuration missing"
assert_equal "$(cat "$HOME/.claude/rules/agent-instructions.md")" "$(cat "$HOME/.codex/AGENTS.md")" \
    "Claude Code and Codex receive the same agent instructions" \
    "Claude Code and Codex agent instructions differ"
assert_equal "${original_sha[.claude/CLAUDE.md]}" "$(sha "$HOME/.claude/CLAUDE.md")" \
    "Existing Claude CLAUDE.md is left unchanged" \
    "Existing Claude CLAUDE.md was changed"
assert_absent "$HOME/.codex/hooks.json" \
    "Codex hook is skipped when RTK is not installed" \
    "Codex hook was created without RTK"

starship_version="$(starship --version 2>/dev/null | head -n 1 || true)"
check "Latest stable Starship installed ($starship_version)" \
    grep -Eq '^starship [0-9]+\.[0-9]+\.[0-9]+' <<< "$starship_version"
assert_equal "$(sha "$HOME/.local/bin/starship")" \
    "$(cat "$state_root/starship-installed-by-dotfiles" 2>/dev/null)" \
    "Starship ownership marker holds the installed binary checksum" \
    "Starship ownership marker is missing or stale"
check "Apply creates no Fish theme state" eval '! compgen -G "$state_root/fish-*"'

check "PowerShell profile initializes Starship" \
    grep -Fq 'starship init powershell' "$HOME/.config/powershell/profile.ps1"

login_env=(env -i HOME="$HOME" USER="${USER:-testuser}" PATH="$system_path" XDG_CONFIG_HOME="$custom_xdg")
# shellcheck disable=SC2016 # Expanded by the login shell
login_check='command -v starship &&
    test "$STARSHIP_CONFIG" = "$HOME/.config/starship.toml" &&
    test "$BAT_CONFIG_PATH" = "$HOME/.config/bat/config"'
check "Bash login startup finds Starship and the managed config paths" \
    "${login_env[@]}" bash -lc "$login_check"
check "Bash interactive startup succeeds" bash -ic exit

if ! full_mode; then
    for optional_command in fish zsh xonsh mise bat zoxide fzf tmux vim; do
        check "Minimal install does not require or install $optional_command" \
            eval "! command -v $optional_command"
    done
    assert_absent "$HOME/.antidote" \
        "Minimal install skips Antidote when Zsh is absent" \
        "Minimal install created Antidote without Zsh"
    assert_absent "$state_root/antidote-installed-by-dotfiles" \
        "Minimal install records no Antidote ownership" \
        "Minimal install recorded unexpected Antidote ownership"
else
    for covered_command in fzf zoxide; do
        check "Optional $covered_command integration is available for startup coverage" \
            command -v "$covered_command"
    done

    assert_nonempty_file "$HOME/.antidote/antidote.zsh" \
        "Latest Antidote checkout installed when Zsh is present" \
        "Automatic Antidote installation is missing"
    assert_equal "$(git -C "$HOME/.antidote" rev-parse HEAD)" \
        "$(cat "$state_root/antidote-installed-by-dotfiles" 2>/dev/null)" \
        "Antidote ownership marker holds the installed commit" \
        "Antidote ownership marker is missing or stale"

    theme_file="/dotfiles/home/dot_config/fish/themes/Catppuccin Mocha.theme"
    # Fish 4 adds a --theme= item to each color
    # Compare only the first item of the color
    # shellcheck disable=SC2016 # Expanded by Fish.
    assert_equal "$(awk '$1 == "fish_color_command" { print $2 }' "$theme_file")" \
        "$(fish -ic 'echo $fish_color_command[1]' 2>/dev/null)" \
        "Interactive Fish loads the Catppuccin Mocha colors" \
        "Interactive Fish did not load the Catppuccin Mocha colors"

    check "Zsh configuration parses, starts, and initializes completion" \
        eval 'zsh -n "$HOME/.zshrc" && zsh -ic "whence -w compdef"'
    zsh_bundle="$HOME/.cache/antidote/zsh_plugins.zsh"
    if grep -Fq zsh-syntax-highlighting "$zsh_bundle" && grep -Fq zsh-autosuggestions "$zsh_bundle"; then
        ok "Antidote generated syntax-highlighting and autosuggestion plugins"
    else
        fail "Antidote did not generate the configured Zsh plugin bundle"
    fi
    check "Zsh syntax highlighting and autosuggestions load at startup" \
        zsh -ic 'typeset -f _zsh_highlight && typeset -f _zsh_autosuggest_start'
    # fzf before 0.48, as in Ubuntu 24.04, has no --zsh and --fish options
    # Test the fzf init scripts only when fzf has these options
    init_tools=(zoxide starship)
    zsh_tool_init='whence -w __zoxide_z prompt_starship_precmd'
    fish_tool_init='functions -q __zoxide_z enable_transience'
    if fzf --zsh >/dev/null 2>&1; then
        init_tools+=(fzf)
        zsh_tool_init+=' fzf-history-widget'
        fish_tool_init+=' fzf_key_bindings; and bind \cr | string match -q "*fzf*"'
    fi
    # Start each shell twice to test the init script caches
    check "Zsh loads ${init_tools[*]}, also from the init caches" \
        eval 'zsh -ic "$zsh_tool_init" >/dev/null && zsh -ic "$zsh_tool_init" >/dev/null'
    init_caches=("${init_tools[@]/#/$HOME/.cache/zsh/}")
    check "Zsh init caches record the tool binary" \
        eval '[ "$(head -qn 1 "${init_caches[@]/%/-init.zsh}" | grep -c "^# /")" -eq ${#init_tools[@]} ]'
    assert_absent "$HOME/.zsh_plugins.zsh" \
        "Generated Zsh plugin bundle stays in the cache" \
        "Generated Zsh plugin bundle leaked into the home directory"
    check "Zsh login startup finds Starship and the managed config paths" \
        "${login_env[@]}" zsh -lc "$login_check"

    check "Fish configuration parses and starts without Fisher" \
        eval 'fish -n "$HOME/.config/fish/config.fish" && fish -ic exit'
    # TERM stops fish 3 terminal warnings
    # Start fish twice to test the Starship cache
    fish_starship_quiet() {
        local check='functions -q enable_transience; or echo missing'
        [ -z "$(TERM=xterm-256color fish -ic "$check" 2>&1)" ] &&
            [ -z "$(TERM=xterm-256color fish -ic "$check" 2>&1)" ]
    }
    check "Fish loads the Starship prompt with no errors, also from its cache" \
        fish_starship_quiet
    check "Fish loads ${init_tools[*]}, also from the init caches" \
        eval 'fish -ic "$fish_tool_init" && fish -ic "$fish_tool_init"'
    check "Fish starts without Fisher and has the managed functions" \
        fish -ic 'not functions -q fisher
            and functions -q tarnow psmem wget lt'
    # shellcheck disable=SC2016 # Expanded by Fish
    check "Fish uses the fixed managed Starship and bat config paths" \
        fish -c 'test "$STARSHIP_CONFIG" = "$HOME/.config/starship.toml"
            and test (string join : $BAT_CONFIG_PATH) = "$HOME/.config/bat/config"'
    # shellcheck disable=SC2016 # Expanded by Fish
    check "Fish keeps the managed Starship config with a custom XDG_CONFIG_HOME" \
        env XDG_CONFIG_HOME="$custom_xdg" fish -c 'source "$HOME/.config/fish/config.fish"
            test "$STARSHIP_CONFIG" = "$HOME/.config/starship.toml"'

    # copyfile_disable VALUE: Zsh and Fish end up with COPYFILE_DISABLE=VALUE
    copyfile_disable() {
        local start=(env -u COPYFILE_DISABLE PATH="$system_path")
        [ "$1" = 1 ] || start=(env COPYFILE_DISABLE="$1" PATH="$system_path")
        "${start[@]}" zsh -fc 'source "$HOME/.profile"; [[ "$COPYFILE_DISABLE" == "$1" ]]' zsh "$1" &&
            "${start[@]}" fish -c 'test "$COPYFILE_DISABLE" = $argv[1]' "$1"
    }
    check "Zsh and Fish default COPYFILE_DISABLE to 1" copyfile_disable 1
    check "Zsh and Fish preserve a COPYFILE_DISABLE override" copyfile_disable keep

    check "Zsh leaves ls unchanged when eza is unavailable" \
        env PATH="$system_path" zsh -ic '(( ! $+commands[eza] )) && (( ! $+aliases[ls] )) && command ls /'

    mock_dir="$(mktemp -d)"
    for mocked_command in eza tar wget; do
        stub "$mock_dir" "$mocked_command" 'printf "%s\n" "$*"'
    done
    stub "$mock_dir" ps \
        '[ "$*" = aux ] || exit 64' \
        'printf "%s\n" "USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND"' \
        'for index in 1 2 3 4 5 6 7 8 9 10 11 12; do' \
        '    printf "owner %d 0.0 %d.0 0 0 ? S 00:00 0:00 process%d\n" "$index" "$index" "$index"' \
        'done'
    # shellcheck disable=SC2016 # Expanded by Zsh
    check "Zsh aliases select eza" \
        env PATH="$mock_dir:$PATH" zsh -ic '
            eza_flags="--group-directories-first --icons=auto"
            [[ "$(ls fixture)" == "$eza_flags fixture" ]] &&
            [[ "$(ll fixture)" == "-l $eza_flags fixture" ]] &&
            [[ "$(la fixture)" == "-a $eza_flags fixture" ]] &&
            [[ "$(lt fixture)" == "-aT $eza_flags fixture" ]]'
    # shellcheck disable=SC2016 # Expanded by Fish
    check "Fish utility functions select eza, resume wget, archive files, and sort memory" \
        env PATH="$mock_dir:$PATH" fish -c '
            set -l flags --group-directories-first --icons=auto
            test "$(ls fixture)" = "$flags fixture"
            and test "$(ll fixture)" = "-l $flags fixture"
            and test "$(la fixture)" = "-a $flags fixture"
            and test "$(lt fixture)" = "-aT $flags fixture"
            and test "$(wget fixture)" = "-c fixture"
            and test "$(tarnow archive.tar.gz fixture)" = "-acf archive.tar.gz fixture"
            and test "$(untar archive.tar.gz)" = "-xvf archive.tar.gz"
            and set -l all (psmem); and test (count $all) -eq 13
            and string match -q "*process12" $all[2]; and string match -q "*process1" $all[13]
            and set -l top (psmem 10); and test (count $top) -eq 11
            and string match -q "*process3" $top[11]'
    # shellcheck disable=SC2016 # Expanded by Fish
    check "Fish functions fall back when eza is missing" \
        env PATH="$system_path" fish -c '
            not command -q eza
            and ls / >/dev/null; and ll / >/dev/null; and la / >/dev/null
            and test "$(echo hi | cat)" = hi
            and if command -q tree
                lt / >/dev/null
            else
                test "$(lt / 2>&1)" = "lt: needs eza or tree"
            end'

    check "Xonsh configuration starts" xonsh -i -c exit
    check "Xonsh uses the fixed managed Starship and bat config paths" \
        xonsh -i -c 'assert $STARSHIP_CONFIG == f"{$HOME}/.config/starship.toml"; assert len($BAT_CONFIG_PATH) == 1 and $BAT_CONFIG_PATH[0] == f"{$HOME}/.config/bat/config"; exit'
    check "bat loads its managed configuration and vendored theme" bat "$HOME/.bashrc"

    rm -f "$mock_dir"/*
    # The zsh mock completion follows the funcstack check that mise prints
    # shellcheck disable=SC2016 # Expanded by the mock shells.
    stub "$mock_dir" mise \
        'case "$1 ${2:-}" in' \
        '  "activate bash"|"activate zsh") echo "export DOTFILES_MISE_MOCK=1" ;;' \
        '  "activate fish") echo "set -gx DOTFILES_MISE_MOCK 1" ;;' \
        "  \"activate xonsh\") echo \"\\\$DOTFILES_MISE_MOCK = '1'\" ;;" \
        '  "completion zsh") echo '\''_mise() { print -r -- mise-mock-word; }; if [ "$funcstack[1]" = _mise ]; then _mise "$@"; else compdef _mise mise; fi'\'' ;;' \
        '  "completion fish") echo "complete -c mise -f -a mise-mock-word" ;;' \
        '  *) exit 2 ;;' \
        'esac'
    mise_shells() {
        local mise_path="PATH=$mock_dir:$PATH"
        env "$mise_path" bash -ic 'test "$DOTFILES_MISE_MOCK" = 1' &&
            env "$mise_path" zsh -ic 'test "$DOTFILES_MISE_MOCK" = 1' &&
            env "$mise_path" fish -ic 'test "$DOTFILES_MISE_MOCK" = 1' &&
            env "$mise_path" xonsh -i -c 'assert $DOTFILES_MISE_MOCK == "1"; exit'
    }
    check "Optional mise activation works in Bash, Zsh, Fish, and Xonsh" mise_shells
    # Calling _mise directly runs the completion function that mise prints, exactly once
    assert_equal mise-mock-word \
        "$(PATH="$mock_dir:$PATH" zsh -ic '[[ $_comps[mise] = _mise ]] && _mise' 2>/dev/null)" \
        "Zsh loads the mise completions from mise" \
        "Zsh did not load the mise completions from mise"
    assert_equal mise-mock-word \
        "$(PATH="$mock_dir:$PATH" fish -ic 'complete -C "mise "' 2>/dev/null)" \
        "Fish loads the mise completions from mise" \
        "Fish did not load the mise completions from mise"
    rm -rf "$mock_dir"

    check "Vim configuration loads" vim -Nu "$HOME/.vimrc" -n -es '+qall'
    tmux_socket="dotfiles-test-$$"
    check "tmux configuration loads" \
        tmux -L "$tmux_socket" -f "$HOME/.config/tmux/tmux.conf" start-server \; show-options -g
    tmux -L "$tmux_socket" kill-server >/dev/null 2>&1 || true

    antidote_commit="$(git -C "$HOME/.antidote" rev-parse HEAD)"
fi

log "Running a full second apply with a newly managed path, including scripts..."
printf '%s\n' 'original later-managed file' > "$HOME/.rollback_reconcile_fixture"
chmod 0644 "$HOME/.rollback_reconcile_fixture"
remember_original .rollback_reconcile_fixture
printf '%s\n' 'managed later file' > "$(chezmoi source-path)/dot_rollback_reconcile_fixture"
if second_apply_output="$(chezmoi apply 2>&1)"; then
    ok "Full second chezmoi apply succeeded"
else
    fail "Full second chezmoi apply failed"
    echo "$second_apply_output"
fi
assert_equal "$backup_id" "$(sed -n '1p' "$state_root/current-backup")" \
    "Second apply kept the original restore point" \
    "Second apply replaced the original restore point"
check "Second apply reports the one new restore-point path" \
    grep -Fqx "Extended the restore point with 1 new managed path(s): $backup_dir" <<< "$second_apply_output"
if grep -Fqx .rollback_reconcile_fixture "$backup_dir/managed-files.txt" &&
        grep -Fqx .rollback_reconcile_fixture "$backup_dir/existing-files.txt" &&
        [ "$(sha "$backup_dir/files/.rollback_reconcile_fixture")" = \
            "${original_sha[.rollback_reconcile_fixture]}" ]; then
    ok "Second apply captured the original of a newly managed path"
else
    fail "Second apply did not capture the original of a newly managed path"
fi
if full_mode; then
    assert_equal "$antidote_commit" "$(git -C "$HOME/.antidote" rev-parse HEAD)" \
        "Second apply leaves the Antidote checkout unchanged" \
        "Second apply changed the Antidote checkout"
fi
managed_diff="$(chezmoi diff --exclude=scripts 2>&1 || echo 'chezmoi diff failed')"
assert_equal '' "$managed_diff" \
    "Managed-file diff is clean after the full scripted re-apply" \
    "Managed-file diff is not clean after the full scripted re-apply"

restore_script="$(mktemp)"
render run_before_00-create-restore-point.sh.tmpl linux > "$restore_script"
manifests_sha="$(cat "$backup_dir"/*.txt | sha256sum)"
assert_equal '' "$(sh "$restore_script" 2>&1 || echo failed)" \
    "Restore-point script is silent when no path is new" \
    "Restore-point script printed output or failed with no new path"
assert_equal "$manifests_sha" "$(cat "$backup_dir"/*.txt | sha256sum)" \
    "Restore-point script keeps the manifests when no path is new" \
    "Restore-point script changed the manifests with no new path"
rm -f "$restore_script"

home_state() { find "$HOME" -printf '%p %y %s %T@ %m\n' | sort | sha256sum; }
home_before_dry_run="$(home_state)"
check "Uninstall dry run succeeds" sh /dotfiles/uninstall.sh --dry-run --yes
assert_equal "$home_before_dry_run" "$(home_state)" \
    "Uninstall dry run changes nothing" \
    "Uninstall dry run changed the home directory"

new_paths="$(grep -Fvx -f "$backup_dir/existing-files.txt" "$backup_dir/managed-files.txt" || true)"
log "Restoring the pre-install state..."
if uninstall_output="$(sh /dotfiles/uninstall.sh --yes 2>&1)"; then
    ok "Uninstall and restore completed"
else
    fail "Uninstall and restore failed"
    echo "$uninstall_output"
fi

for path in "${!original_sha[@]}"; do
    if [ "$(sha "$HOME/$path")" = "${original_sha[$path]}" ] &&
            [ "$(stat -c '%a' "$HOME/$path")" = "${original_mode[$path]}" ]; then
        ok "Original ~/$path has its content and mode"
    else
        fail "Original ~/$path was not restored exactly"
    fi
done
if [ -L "$HOME/.zprofile" ] && [ "$(readlink "$HOME/.zprofile")" = .bashrc ]; then
    ok "Original .zprofile symlink restored"
else
    fail "Original .zprofile symlink was not restored"
fi

# all_new_paths_removed: no path that was absent before install remains
all_new_paths_removed() {
    local path
    while IFS= read -r path; do
        [ ! -e "$HOME/$path" ] && [ ! -L "$HOME/$path" ] || return 1
    done <<< "$new_paths"
}
check "All $(wc -l <<< "$new_paths") newly managed paths removed" all_new_paths_removed
check "Installed Nerd Font files removed" every_font font_removed
for removed in "$HOME/.local/bin/starship" "$state_root/starship-installed-by-dotfiles" \
        "$HOME/.antidote" "$state_root/antidote-installed-by-dotfiles" \
        "$state_root/current-backup" "$HOME/.local/share/chezmoi"; do
    assert_absent "$removed" "Uninstall removed ${removed/#"$HOME"/\~}" \
        "Uninstall left ${removed/#"$HOME"/\~}"
done
assert_nonempty_file "$state_root/last-uninstall-snapshot" \
    "Pre-uninstall recovery snapshot recorded" \
    "Pre-uninstall recovery snapshot missing"
assert_equal "$backup_id" "$(sed -n '1p' "$state_root/last-restored-backup")" \
    "Consumed restore-point identifier recorded" \
    "Consumed restore-point identifier was not recorded"

print_summary_and_exit

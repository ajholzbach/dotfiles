#!/usr/bin/env bash
# Install with tools = true on a disposable macOS runner, apply again, and
# uninstall. It uses the real HOME and Homebrew, so it runs only in CI.
set -u

[ "${CI:-}" = true ] || { echo 'Run this test only on a disposable CI runner.' >&2; exit 1; }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
LOGS="$(mktemp -d)"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

passed=0 failed=0
check() {
    local message="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "ok   $message"
        passed=$((passed + 1))
    else
        echo "FAIL $message"
        failed=$((failed + 1))
    fi
}

run() {
    local log="$LOGS/$1"
    shift
    "$@" >"$log" 2>&1
    local status=$?
    cat "$log"
    return "$status"
}

mkdir -p "$(dirname "$SOURCE")" "$LOGS/original"
rsync -a --exclude .git "$REPO/" "$SOURCE/"
printf '%s\n' '# original bashrc' >"$HOME/.bashrc"
printf '%s\n' '# >>> other tool >>>' 'export OTHER_TOOL=1' '# <<< other tool <<<' >"$HOME/.bash_profile"
cp -p "$HOME/.bashrc" "$HOME/.bash_profile" "$LOGS/original/"

echo '== first apply'
run apply1 chezmoi init --apply --promptBool tools=true
check 'first apply succeeds' test "$?" -eq 0
# The other checks mean nothing without a first apply.
[ "$failed" -eq 0 ] || exit 1
check 'restore point holds the original .bashrc' \
    grep -Fqx .bashrc "$STATE/backups/$(cat "$STATE/current-backup")/existing-files.txt"
check 'Starship installed into ~/.local/bin' "$HOME/.local/bin/starship" --version
check 'mise bootstrap ran' grep -Fq 'mise bootstrap' "$LOGS/apply1"
for tool in bat eza fish fzf zoxide; do
    check "$tool installed with Homebrew packages" test -x "/opt/homebrew/bin/$tool"
done
check 'Fisher installed every plugin' \
    sh -c "[ \"\$(fish -c 'fisher list' | sort)\" = \"\$(sort '$HOME/.config/fish/fish_plugins')\" ]"
check 'Antidote installed' test -f "$HOME/.antidote/antidote.zsh"
check 'MesloLGS Nerd Font installed' test -f "$HOME/Library/Fonts/MesloLGSNerdFont-Regular.ttf"
check '.bash_profile keeps the other block' grep -Fqx 'export OTHER_TOOL=1' "$HOME/.bash_profile"
check 'zsh interactive startup succeeds' zsh -ic exit
check 'bash login startup finds Starship' bash -lc 'command -v starship'
check 'Fish loads Catppuccin' sh -c "fish -ic 'echo \$fish_color_command' | grep -qx 89b4fa"
check 'Fish stores no universal colors' \
    sh -c "! grep -q fish_color '$HOME/.config/fish/fish_variables' 2>/dev/null"

echo '== second apply'
run apply2 chezmoi apply
check 'second apply succeeds' test "$?" -eq 0
check 'managed files match the source' test -z "$(chezmoi diff --exclude=scripts)"

echo '== uninstall'
run uninstall sh "$SOURCE/uninstall.sh" --yes
check 'uninstall succeeds' test "$?" -eq 0
check '.bashrc restored' cmp "$LOGS/original/.bashrc" "$HOME/.bashrc"
check '.bash_profile restored' cmp "$LOGS/original/.bash_profile" "$HOME/.bash_profile"
check 'config.fish removed' test ! -e "$HOME/.config/fish/config.fish"
check 'mise tools config removed' test ! -e "$HOME/.config/mise/conf.d/10-dotfiles-tools.toml"
check 'Starship removed' test ! -e "$HOME/.local/bin/starship"
check 'Antidote removed' test ! -e "$HOME/.antidote"
check 'chezmoi source purged' test ! -e "$SOURCE"

echo "== $passed passed, $failed failed"
[ "$failed" -eq 0 ]

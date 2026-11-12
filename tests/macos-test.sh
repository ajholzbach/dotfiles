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

source "$REPO/tests/lib/testlib.sh"

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
# The other checks mean nothing without a first apply
[ "$TEST_FAIL" -eq 0 ] || exit 1
# The first apply removes the ~/.local/bin/chezmoi that bash hashed
# Find chezmoi again on PATH
hash -r
check 'restore point holds the original .bashrc' \
    grep -Fqx .bashrc "$STATE/backups/$(cat "$STATE/current-backup")/existing-files.txt"
for tool in antidote chezmoi starship; do
    check "$tool installed with Homebrew" brew list --formula "$tool"
done
check 'one-line chezmoi copy removed' test ! -e "$HOME/.local/bin/chezmoi"
check 'Starship not installed into ~/.local/bin' test ! -e "$HOME/.local/bin/starship"
check 'MesloLGS Nerd Font installed with Homebrew' brew list --cask font-meslo-lg-nerd-font
check 'mise bootstrap ran' grep -Fq 'mise bootstrap' "$LOGS/apply1"
for tool in bat eza fish fzf zoxide; do
    check "$tool installed with Homebrew packages" test -x "/opt/homebrew/bin/$tool"
done
check 'Fisher installed every plugin' \
    sh -c "[ \"\$(fish -c 'fisher list' | sort)\" = \"\$(sort '$HOME/.config/fish/fish_plugins')\" ]"
check '.bash_profile keeps the other block' grep -Fqx 'export OTHER_TOOL=1' "$HOME/.bash_profile"
check 'zsh interactive startup succeeds' zsh -ic exit
check 'zsh loads Antidote plugins from Homebrew' test -s "$HOME/.cache/antidote/zsh_plugins.zsh"
check 'bash login startup finds Starship' bash -lc 'command -v starship'
check 'Fish loads Catppuccin' sh -c "fish -ic 'echo \$fish_color_command' | grep -qx 89b4fa"
check 'Fish stores no universal colors' \
    sh -c "! grep -q fish_color '$HOME/.config/fish/fish_variables' 2>/dev/null"

echo '== second apply'
run apply2 chezmoi apply
check 'second apply succeeds' test "$?" -eq 0
check 'managed files match the source' test -z "$(chezmoi diff --exclude=scripts)"
check 'second apply leaves no install script pending' \
    sh -c "! chezmoi status --include=scripts | grep -E '15-mise-bootstrap|36-install-fisher'"

echo '== uninstall'
# Run the uninstall command from docs/uninstall.md
run uninstall sh "$(chezmoi source-path)/../uninstall.sh" --yes
check 'uninstall succeeds' test "$?" -eq 0
check '.bashrc restored' cmp "$LOGS/original/.bashrc" "$HOME/.bashrc"
check '.bash_profile restored' cmp "$LOGS/original/.bash_profile" "$HOME/.bash_profile"
check 'config.fish removed' test ! -e "$HOME/.config/fish/config.fish"
check 'mise tools config removed' test ! -e "$HOME/.config/mise/conf.d/10-dotfiles-tools.toml"
check 'Homebrew packages stay installed' brew list --formula starship
check 'chezmoi source purged' test ! -e "$SOURCE"

print_summary_and_exit

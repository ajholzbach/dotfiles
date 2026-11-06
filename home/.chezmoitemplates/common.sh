#!/usr/bin/env sh
set -eu

# shellcheck disable=SC2034 # Not every script uses the state directory
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
installer=''

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

# find_tool NAME: print NAME from PATH or from Homebrew. A Homebrew installed
# during this apply is not on PATH yet.
find_tool() {
    command -v "$1" 2>/dev/null && return 0
    for candidate in "/opt/homebrew/bin/$1" "/usr/local/bin/$1"; do
        [ -x "$candidate" ] && printf '%s\n' "$candidate" && return 0
    done
    return 1
}

# download_installer URL: download URL to a temporary file named by $installer
download_installer() {
    [ -z "$installer" ] || rm -f "$installer"
    installer="$(mktemp)"
    curl --proto '=https' --tlsv1.2 -fsSL -o "$installer" "$1"
}

trap '[ -z "$installer" ] || rm -f "$installer"' EXIT
trap 'exit 1' HUP INT TERM

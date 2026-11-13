#!/usr/bin/env bash
# Tests the recommended tools install on a bare Ubuntu or Arch system
set -euo pipefail

source /dotfiles/tests/lib/testlib.sh

SOURCE=/dotfiles/home
PROMPT=tools

# These targets render only when tools is true on Linux or macOS
TOOL_TARGETS=(
    .chezmoiscripts/run_onchange_after_15-mise-bootstrap.sh.tmpl
    .chezmoiscripts/run_onchange_after_36-install-fisher.sh.tmpl
    dot_config/mise/conf.d/10-dotfiles-tools.toml
)
MISE_CONFIG=.config/mise/conf.d/10-dotfiles-tools.toml

# source_template DATA TEMPLATE: render TEMPLATE from the source with DATA
source_template() {
    chezmoi execute-template --source "$SOURCE" --override-data "$1" "$2"
}

# render DATA FILE: render a source file with DATA
render() {
    chezmoi execute-template --source "$SOURCE" --override-data "$1" \
        --file "$SOURCE/$2"
}

# query TEMPLATE: evaluate TEMPLATE against the applied source and config
query() {
    chezmoi execute-template "$1"
}

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

# mock_dir: print a new directory for mock commands
mock_dir() {
    mktemp -d -p "$fixture"
}

# renders DATA TARGET: succeed when TARGET produces a file for DATA.
# Return 2 when the template fails to render.
renders() {
    local output
    if [ "${2##*/}" = "${MISE_CONFIG##*/}" ]; then
        output="$(render "$1" .chezmoiignore)" || return 2
        ! grep -Fqx "$MISE_CONFIG" <<< "$output"
    else
        output="$(render "$1" "$2")" || return 2
        [ -n "$output" ]
    fi
}

log "Checking which tools targets each system renders..."
for os in darwin linux windows; do
    for tools in true false absent; do
        case "$tools" in
            absent) override="{\"chezmoi\":{\"os\":\"$os\"}}" ;;
            *) override="{\"tools\":$tools,\"chezmoi\":{\"os\":\"$os\"}}" ;;
        esac
        expect=1
        [ "$tools" = true ] && [ "$os" != windows ] && expect=0
        for target in "${TOOL_TARGETS[@]}"; do
            status=0
            renders "$override" "$target" || status=$?
            if [ "$status" -eq "$expect" ]; then
                ok "tools=$tools on $os $([ "$expect" -eq 0 ] && echo renders || echo skips) ${target##*/}"
            else
                fail "tools=$tools on $os gave status $status for ${target##*/}, expected $expect"
            fi
        done
    done
done

log "Checking the chezmoi config template..."
config_template="$SOURCE/.chezmoi.toml.tmpl"

# init_config FILE ARG...: render the config template to FILE with no TTY
init_config() {
    local file="$1"
    shift
    chezmoi execute-template --init "$@" --file "$config_template" \
        < /dev/null > "$file"
}

# config_value FILE TEMPLATE: evaluate TEMPLATE with the config in FILE
config_value() {
    chezmoi --config "$1" execute-template "$2"
}

if init_config "$fixture/windows.toml" --override-data '{"chezmoi":{"os":"windows"}}' &&
        [ "$(config_value "$fixture/windows.toml" '{{ .tools }}')" = false ]; then
    ok "Windows skips the tools prompt"
else
    fail "Windows prompted or enabled the tools install"
fi

if init_config "$fixture/saved.toml" --override-data '{"tools":true}' &&
        [ "$(config_value "$fixture/saved.toml" '{{ .tools }}')" = true ]; then
    ok "chezmoi init keeps a saved tools answer without prompting"
else
    fail "chezmoi init lost or prompted for a saved tools answer"
fi

if init_config "$fixture/flag.toml" --promptBool "$PROMPT=true" &&
        [ "$(config_value "$fixture/flag.toml" '{{ .tools }}')" = true ]; then
    ok "--promptBool $PROMPT=true enables the tools install"
else
    fail "--promptBool $PROMPT=true did not enable the tools install"
fi

kube_data='{"tools":false,"kube":{"starshipContexts":"context_alias = \"$rest\"","nested":{"key":"value"}}}'
if init_config "$fixture/kube.toml" --override-data "$kube_data" &&
        [ "$(config_value "$fixture/kube.toml" '{{ .kube | toJson }}')" = \
            "$(source_template "$kube_data" '{{ .kube | toJson }}')" ]; then
    ok "chezmoi init keeps machine-local kube data"
else
    fail "chezmoi init lost machine-local kube data"
fi

log "Checking the bootstrap script against a mock mise..."
# An installed mise runs bootstrap with the managed config. On macOS, an
# installed Homebrew is reused.
for os in linux darwin; do
    mocks="$(mock_dir)"
    stub "$mocks" brew 'exit 0'
    stub "$mocks" mise '[ "$1" != --version ] || { echo 2026.11.6; exit; }' \
        'printf "%s %s\n" "$XDG_CONFIG_HOME" "$*" >> "$MOCK_LOG"'
    render "{\"tools\":true,\"chezmoi\":{\"os\":\"$os\"}}" "${TOOL_TARGETS[0]}" > "$mocks/install.sh"
    if HOME="$mocks" MOCK_LOG="$mocks/log" PATH="$mocks:$PATH" sh "$mocks/install.sh" >/dev/null &&
            [ "$(tail -n 1 "$mocks/log")" = "$mocks/.config bootstrap --only packages,tools --yes" ]; then
        ok "bootstrap script on $os runs mise bootstrap for packages and tools"
    else
        fail "bootstrap script on $os ran the wrong mise commands"
    fi
done

# On macOS, Homebrew provides chezmoi after the one-line install
# The bootstrap script removes the ~/.local/bin copy
mocks="$(mock_dir)"
stub "$mocks/brew-prefix/bin" chezmoi 'exit 0'
stub "$mocks/.local/bin" chezmoi 'exit 0'
stub "$mocks" brew "echo '$mocks/brew-prefix'"
stub "$mocks" mise '[ "$1" != --version ] || echo 2026.11.6'
render '{"tools":true,"chezmoi":{"os":"darwin"}}' "${TOOL_TARGETS[0]}" > "$mocks/install.sh"
if HOME="$mocks" PATH="$mocks:$PATH" sh "$mocks/install.sh" >/dev/null &&
        [ ! -e "$mocks/.local/bin/chezmoi" ]; then
    ok "bootstrap script on macOS removes ~/.local/bin/chezmoi when Homebrew provides chezmoi"
else
    fail "bootstrap script on macOS kept ~/.local/bin/chezmoi next to the Homebrew copy"
fi

# On Apple silicon with tools, Homebrew installs Starship, Antidote, and the font
# The dotfiles installers and the font externals render nothing there
homebrew_owned() {
    local data="{\"tools\":true,\"chezmoi\":{\"os\":\"darwin\",\"arch\":\"$1\"}}"
    [ -z "$(render "$data" .chezmoiscripts/run_after_12-install-starship.sh.tmpl | tr -d '[:space:]')" ] &&
        [ -z "$(render "$data" .chezmoiscripts/run_after_16-install-antidote.sh.tmpl | tr -d '[:space:]')" ]
}
no_font_externals() {
    ! render '{"tools":true,"chezmoi":{"os":"darwin"}}' .chezmoiexternal.toml.tmpl | grep -q '^\['
}
if homebrew_owned arm64 && ! homebrew_owned amd64 && no_font_externals; then
    ok "macOS with tools leaves Starship, Antidote, and the font to Homebrew"
else
    fail "macOS with tools still renders a dotfiles installer that Homebrew replaces"
fi

# A mise older than 2026.10.9 ignores [bootstrap.apt.sources]
# The bootstrap script updates it first
stub "$mocks" mise \
    '[ "$1" != --version ] || { [ -e "$HOME/updated" ] && echo 2026.11.6 || echo 2026.10.8; exit; }' \
    '[ "$1" != self-update ] || { touch "$HOME/updated"; exit; }' \
    'printf "%s\n" "$*" >> "$HOME/log"'
if HOME="$mocks" PATH="$mocks:$PATH" sh "$mocks/install.sh" >/dev/null 2>&1 &&
        [ -e "$mocks/updated" ] && grep -Fqx 'bootstrap --only packages,tools --yes' "$mocks/log"; then
    ok "bootstrap script updates a mise older than 2026.10.9, then runs bootstrap"
else
    fail "bootstrap script did not update an old mise before bootstrap"
fi

# A mise that cannot update itself stops the apply with a recovery hint
stub "$mocks" mise '[ "$1" = --version ] && echo 2024.1.0' 'exit 2'
if ! mock_output="$(HOME="$mocks" PATH="$mocks:$PATH" sh "$mocks/install.sh" 2>&1)" &&
        grep -Fq 'is older than 2026.10.9' <<< "$mock_output" &&
        grep -Fq "$PROMPT=false" <<< "$mock_output"; then
    ok "bootstrap script stops with a recovery hint when mise is too old"
else
    fail "bootstrap script ignored a mise that is too old"
fi

# add-apt-repository writes its own source for the fish 4 PPA
# Add one, so the install must replace it with the mise source
ppa_source=''
codename="$(. /etc/os-release && printf '%s' "${UBUNTU_CODENAME:-}")"
if [ -n "$codename" ]; then
    ppa_source="/etc/apt/sources.list.d/fish-shell-ubuntu-release-4-$codename.sources"
    printf '%s\n' 'Types: deb' 'URIs: https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu/' \
        "Suites: $codename" 'Components: main' 'Signed-By: /usr/share/keyrings/other.gpg' |
        sudo tee "$ppa_source" >/dev/null
fi

log "Installing the dotfiles with recommended tools..."
if ! apply_output="$(chezmoi --use-builtin-git=true init --apply \
        --promptBool "$PROMPT=true" file:///dotfiles 2>&1)"; then
    echo "$apply_output"
    fail "chezmoi init --apply with tools failed"
    print_summary_and_exit
fi
ok "chezmoi init --apply with tools succeeded"
if [ -n "$ppa_source" ]; then
    assert_absent "$ppa_source" \
        "The install replaced the add-apt-repository source for the fish 4 PPA" \
        "The add-apt-repository source for the fish 4 PPA is still present"
fi

# uninstall removes the mise config
# Read the expected packages from the mise config now
mise_config="$HOME/$MISE_CONFIG"
manager="$(command -v apt-get >/dev/null && echo apt || echo pacman)"
mapfile -t expected_packages < <(
    sed -n "s/^\"$manager:\([^\"]*\)\".*/$manager \1/p" "$mise_config"
    sed -n '/^\[tools\]/,/^\[/s/^"\{0,1\}\([a-z0-9_:./-]*\)"\{0,1\} = .*/mise \1/p' "$mise_config"
)
[ "${#expected_packages[@]}" -gt 0 ] || fail "No packages to check in $mise_config"

# installed MANAGER PACKAGE: succeed when MANAGER reports PACKAGE as installed
installed() {
    case "$1" in
        apt) dpkg-query -W -f='${Status}\n' "$2" 2>/dev/null | grep -q ' installed$' ;;
        pacman) pacman -Q "$2" >/dev/null 2>&1 ;;
        mise) "$HOME/.local/bin/mise" ls --installed "$2" 2>/dev/null | grep -q . ;;
        *) return 1 ;;
    esac
}

# check_packages SUFFIX: check every package from the mise config
check_packages() {
    local entry manager package
    for entry in "${expected_packages[@]}"; do
        read -r manager package <<< "$entry"
        if installed "$manager" "$package"; then
            ok "$entry is installed$1"
        else
            fail "$entry is not installed$1"
        fi
    done
}
check_packages ''

if fish_version="$(fish --version 2>&1)" && grep -Eq 'version ([4-9]|[1-9][0-9])\.' <<< "$fish_version"; then
    ok "Fish 4 or later is installed ($fish_version)"
else
    fail "Fish 4 or later is not installed ($fish_version)"
fi

if zsh_alias="$(zsh -ic 'alias ls' 2>&1)" && grep -Fq eza <<< "$zsh_alias"; then
    ok "Zsh finds the installed eza at startup"
else
    echo "$zsh_alias"
    fail "Zsh does not find the installed eza at startup"
fi

if [ -f "$HOME/.antidote/antidote.zsh" ]; then
    ok "Antidote installs in the same apply that installs zsh"
else
    fail "Antidote is missing after the apply that installed zsh"
fi

if fisher_plugins="$(fish -c 'fisher list' 2>&1)" &&
        [ "$(sort <<< "$fisher_plugins")" = "$(sort "$HOME/.config/fish/fish_plugins")" ]; then
    ok "Fisher installed exactly the plugins in fish_plugins"
else
    echo "$fisher_plugins"
    fail "Fisher plugins differ from fish_plugins"
fi

log "Running every tools script again without root..."
# tool_scripts: print the run_onchange_ tool scripts that chezmoi would run
tool_scripts() {
    chezmoi status --include=scripts 2>/dev/null |
        grep -E '(15-mise-bootstrap|36-install-fisher)' || true
}

# chezmoi records run_onchange_ scripts in entryState
chezmoi state delete-bucket --bucket=entryState
pending="$(tool_scripts)"
if grep -Fq 15-mise-bootstrap.sh <<< "$pending" &&
        grep -Fq 36-install-fisher.sh <<< "$pending"; then
    ok "Clearing the script state queues the tools scripts again"
else
    echo "$pending"
    fail "Clearing the script state did not queue the tools scripts"
fi

# A sudo that always fails proves each script finds its work already done
mocks="$(mock_dir)"
stub "$mocks" sudo 'echo "unexpected sudo $*" >&2' 'exit 1'
if rerun_output="$(PATH="$mocks:$PATH" chezmoi apply 2>&1)" && [ -z "$(tool_scripts)" ]; then
    ok "Every tools script runs again without needing root"
else
    echo "$rerun_output"
    fail "A tools script needed root or did not run"
fi

log "Replacing Fisher with a copy that Fisher does not own..."
fish -c 'set -U _fisher_plugins (string match -v jorgebucaran/fisher $_fisher_plugins)
    set -e -U _fisher_jorgebucaran_2F_fisher_files'
chezmoi state delete-bucket --bucket=entryState
fisher_file="$HOME/.config/fish/functions/fisher.fish"
if adopt_output="$(chezmoi apply 2>&1)" &&
        fish -c 'contains jorgebucaran/fisher $_fisher_plugins' &&
        [ -f "$fisher_file" ] && [ -z "$(find "$HOME/.config/fish" -name "*.dotfiles-old")" ]; then
    ok "Fisher takes ownership of a fisher.fish that it did not install"
else
    echo "$adopt_output"
    fail "Fisher did not take ownership of an existing fisher.fish"
fi

if managed_diff="$(chezmoi diff --exclude=scripts)" && [ -z "$managed_diff" ]; then
    ok "Managed files are unchanged after Fisher and mise run"
else
    echo "$managed_diff"
    fail "A tool changed a managed file"
fi

log "Uninstalling the dotfiles..."
if uninstall_output="$(sh /dotfiles/uninstall.sh --yes 2>&1)"; then
    ok "Uninstall succeeds after a tools install"
else
    echo "$uninstall_output"
    fail "Uninstall failed after a tools install"
fi
check_packages ' and kept it after uninstall'

print_summary_and_exit

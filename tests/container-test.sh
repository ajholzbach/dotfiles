#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="/dotfiles/tests"
source "$SCRIPT_ROOT/lib/testlib.sh"

log "Setting up chezmoi source directory..."
mkdir -p ~/.local/share
cp -r /dotfiles ~/.local/share/chezmoi

echo ""
log "Running chezmoi apply..."
apply_output=""
if apply_output="$(chezmoi apply 2>&1)"; then
    apply_status=0
else
    apply_status=$?
fi
echo "$apply_output" | grep -E "^(Installing|Downloading|Error)" || true

if [ $apply_status -ne 0 ]; then
    echo ""
    echo "chezmoi apply failed (exit $apply_status); full output:"
    echo "$apply_output"
    exit $apply_status
fi

log "Re-running chezmoi apply for idempotency..."
second_apply_output=""
if second_apply_output="$(chezmoi apply --exclude=scripts 2>&1)"; then
    second_apply_status=0
else
    second_apply_status=$?
fi

if [ $second_apply_status -ne 0 ]; then
    fail "Second chezmoi apply failed"
    echo "$second_apply_output"
else
    ok "Second chezmoi apply succeeded with scripts excluded"
fi

assert_clean_diff

echo ""
log "Verification Results:"
echo ""

if command -v starship >/dev/null 2>&1; then
    ok "Starship installed ($(starship --version | head -n1))"
else
    fail "Starship missing"
fi

if command -v mise >/dev/null 2>&1; then
    ok "mise installed ($(mise --version | head -n1))"
else
    fail "mise missing"
fi

if mise ls --installed usage >/dev/null 2>&1; then
    ok "usage installed via mise"
else
    fail "usage missing"
fi

assert_file "$HOME/.antidote/antidote.zsh" \
    "Antidote installed" \
    "Antidote missing"

assert_file "$HOME/.zshrc" \
    ".zshrc installed" \
    ".zshrc missing"

assert_file "$HOME/.config/starship.toml" \
    "Starship config installed" \
    "Starship config missing"

assert_file "$HOME/.config/fish/completions/mise.fish" \
    "mise fish completions installed" \
    "mise fish completions missing"

assert_file "$HOME/.config/fish/completions/chezmoi.fish" \
    "chezmoi fish completions installed" \
    "chezmoi fish completions missing"

assert_file "$HOME/.config/fish/completions/bat.fish" \
    "bat fish completions installed" \
    "bat fish completions missing"

assert_file "$HOME/.config/fish/completions/rg.fish" \
    "rg fish completions installed" \
    "rg fish completions missing"

assert_file "$HOME/.config/fish/completions/fd.fish" \
    "fd fish completions installed" \
    "fd fish completions missing"

assert_fonts 4

if [ "$(git config --global --get core.excludesfile || true)" = "$HOME/.gitignore_global" ]; then
    ok "git global excludesfile configured"
else
    fail "git global excludesfile not configured"
fi

if command -v bat >/dev/null 2>&1 && bat --list-themes | grep -Fq "Catppuccin Mocha"; then
    ok "bat cache built with Catppuccin theme"
else
    fail "bat cache missing Catppuccin theme"
fi

if zsh -ic 'exit' >/dev/null 2>&1; then
    ok "zsh startup succeeded"
else
    fail "zsh startup failed"
fi

if fish -ic 'exit' >/dev/null 2>&1; then
    ok "fish startup succeeded"
else
    fail "fish startup failed"
fi

if fish -ic 'functions -q fisher' >/dev/null 2>&1; then
    ok "Fisher available in fish"
else
    fail "Fisher missing in fish"
fi

print_summary_and_exit

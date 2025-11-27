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
apply_status=0
if ! apply_output="$(chezmoi apply 2>&1)"; then
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
if ! chezmoi apply >/dev/null 2>&1; then
    fail "Second chezmoi apply failed"
else
    ok "Second chezmoi apply succeeded"
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

assert_file "$HOME/.antidote/antidote.zsh" \
    "Antidote installed" \
    "Antidote missing"

assert_file "$HOME/.zshrc" \
    ".zshrc installed" \
    ".zshrc missing"

assert_file "$HOME/.config/starship.toml" \
    "Starship config installed" \
    "Starship config missing"

assert_fonts 4

print_summary_and_exit

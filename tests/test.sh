#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building Docker image..."
docker build -t dotfiles-test "$SCRIPT_DIR"

echo ""
echo "Running chezmoi installation test..."
echo ""

docker run --rm \
    -v "$REPO_ROOT:/dotfiles:ro" \
    dotfiles-test \
    bash -c '
        set -euo pipefail
        echo "==> Setting up chezmoi source directory..."
        mkdir -p ~/.local/share
        cp -r /dotfiles ~/.local/share/chezmoi

        echo ""
        echo "==> Running chezmoi apply..."
        chezmoi apply 2>&1 | grep -E "^(Installing|Downloading|Error)" || true

        echo ""
        echo "==> Verification Results:"
        echo ""

        PASS=0
        FAIL=0

        if command -v starship >/dev/null 2>&1; then
            echo "  ✓ Starship installed ($(starship --version | head -n1))"
            ((PASS++))
        else
            echo "  ✗ Starship missing"
            ((FAIL++))
        fi

        if [ -f ~/.antidote/antidote.zsh ]; then
            echo "  ✓ Antidote installed"
            ((PASS++))
        else
            echo "  ✗ Antidote missing"
            ((FAIL++))
        fi

        if [ -f ~/.local/share/fonts/MesloLGS\ NF\ Regular.ttf ]; then
            FONT_COUNT=$(find ~/.local/share/fonts -name "MesloLGS NF*.ttf" 2>/dev/null | wc -l | tr -d ' ')
            echo "  ✓ MesloLGS NF fonts installed ($FONT_COUNT variants)"
            ((PASS++))
        else
            echo "  ✗ Fonts missing"
            ((FAIL++))
        fi

        echo ""
        echo "==> Summary: $PASS passed, $FAIL failed"

        if [ $FAIL -gt 0 ]; then
            exit 1
        fi

        echo ""
        echo "==> All tests passed!"
    '

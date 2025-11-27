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
    bash /dotfiles/tests/container-test.sh

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building Docker image..."
docker build -t dotfiles-test "$SCRIPT_DIR"

# Pass through GITHUB_TOKEN (from env or `gh auth token`) so mise/etc avoid
# anonymous GitHub API rate limits. The token never lives in the image.
GH_TOKEN_ARGS=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    GH_TOKEN_ARGS=(-e "GITHUB_TOKEN=$GITHUB_TOKEN")
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    GH_TOKEN_ARGS=(-e "GITHUB_TOKEN=$(gh auth token)")
fi

echo ""
echo "Running chezmoi installation test..."
echo ""

docker run --rm \
    -v "$REPO_ROOT:/dotfiles:ro" \
    "${GH_TOKEN_ARGS[@]}" \
    dotfiles-test \
    bash /dotfiles/tests/container-test.sh

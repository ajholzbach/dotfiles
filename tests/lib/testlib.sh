#!/usr/bin/env bash
# Lightweight assertion helpers for container tests
set -euo pipefail

TEST_PASS=0
TEST_FAIL=0

log() {
    echo "==> $*"
}

ok() {
    echo "  ✓ $*"
    TEST_PASS=$((TEST_PASS + 1))
}

fail() {
    echo "  ✗ $*"
    TEST_FAIL=$((TEST_FAIL + 1))
}

assert_cmd() {
    local cmd="$1"
    local success_msg="$2"
    local fail_msg="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$success_msg"
    else
        fail "$fail_msg"
    fi
}

assert_file() {
    local path="$1"
    local success_msg="$2"
    local fail_msg="$3"
    if [ -f "$path" ]; then
        ok "$success_msg"
    else
        fail "$fail_msg"
    fi
}

assert_fonts() {
    local min_expected="$1"
    local count=0
    for dir in "$HOME/.local/share/fonts" "$HOME/Library/Fonts"; do
        [ -d "$dir" ] || continue
        local found
        found=$(find "$dir" -name "MesloLGS NF*.ttf" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$found" -gt 0 ]; then
            count=$((count + found))
        fi
    done

    if [ "$count" -ge "$min_expected" ]; then
        ok "MesloLGS NF fonts installed ($count variants)"
    else
        fail "Fonts missing (found $count, expected at least $min_expected)"
    fi
}

assert_clean_diff() {
    local diff_output=""
    diff_output="$(chezmoi diff 2>/dev/null || true)"
    if [ -z "$diff_output" ]; then
        ok "chezmoi diff clean after re-apply"
    else
        fail "chezmoi diff not clean after re-apply"
        echo "$diff_output"
    fi
}

print_summary_and_exit() {
    echo ""
    echo "==> Summary: $TEST_PASS passed, $TEST_FAIL failed"
    if [ "$TEST_FAIL" -gt 0 ]; then
        exit 1
    fi
    echo ""
    echo "==> All tests passed!"
}

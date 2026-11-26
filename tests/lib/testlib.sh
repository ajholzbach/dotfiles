#!/usr/bin/env bash
# Assertion helpers for the test suites
# Each suite sets its own shell options

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

check() {
    local message="$1"
    shift
    if "$@" >/dev/null 2>&1; then ok "$message"; else fail "$message"; fi
}

stub() {
    local dir="$1" name="$2"
    shift 2
    mkdir -p "$dir"
    printf '%s\n' '#!/bin/sh' "$@" > "$dir/$name"
    chmod +x "$dir/$name"
}

assert_nonempty_file() {
    local path="$1"
    local success_msg="$2"
    local fail_msg="$3"
    if [ -s "$path" ]; then
        ok "$success_msg"
    else
        fail "$fail_msg"
    fi
}

assert_absent() {
    local path="$1"
    local success_msg="$2"
    local fail_msg="$3"
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        ok "$success_msg"
    else
        fail "$fail_msg"
    fi
}

assert_equal() {
    local expected="$1"
    local actual="$2"
    local success_msg="$3"
    local fail_msg="$4"
    if [ "$expected" = "$actual" ]; then
        ok "$success_msg"
    else
        fail "$fail_msg (expected '$expected', got '$actual')"
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

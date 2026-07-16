#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/script-coverage.tsv"
SCRIPTS_DIR="$REPO_ROOT/home/.chezmoiscripts"

if [ ! -f "$MANIFEST" ]; then
    echo "Missing chezmoi script coverage manifest: $MANIFEST" >&2
    exit 1
fi

if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "Missing chezmoi scripts directory: $SCRIPTS_DIR" >&2
    exit 1
fi

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-script-coverage.XXXXXX")"
actual_list="$temporary_dir/actual"
manifest_list="$temporary_dir/manifest"

cleanup() {
    rm -rf "$temporary_dir"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

: > "$actual_list"
: > "$manifest_list"

while IFS= read -r script_path; do
    [ -n "$script_path" ] || continue
    printf '%s\n' "${script_path#"$REPO_ROOT/"}" >> "$actual_list"
done < <(find "$SCRIPTS_DIR" \( -type f -o -type l \) -name 'run_*' -print)
LC_ALL=C sort -o "$actual_list" "$actual_list"

line_number=0
while IFS=$'\t' read -r script_path suites unexpected; do
    line_number=$((line_number + 1))

    case "$script_path" in
        ''|'#'*)
            continue
            ;;
    esac

    if [ -n "${unexpected:-}" ] || [ -z "${suites:-}" ]; then
        echo "Malformed coverage manifest entry on line $line_number" >&2
        exit 1
    fi

    case "$script_path" in
        home/.chezmoiscripts/*)
            ;;
        *)
            echo "Invalid script path on manifest line $line_number: $script_path" >&2
            exit 1
            ;;
    esac

    if [ ! -f "$REPO_ROOT/$script_path" ] && [ ! -L "$REPO_ROOT/$script_path" ]; then
        echo "Manifest references a missing script: $script_path" >&2
        exit 1
    fi

    old_ifs="$IFS"
    IFS=','
    # Intentional word splitting validates each comma-delimited suite.
    set -- $suites
    IFS="$old_ifs"
    if [ "$#" -eq 0 ]; then
        echo "Manifest entry has no Docker suites: $script_path" >&2
        exit 1
    fi
    seen_suites=','
    for suite in "$@"; do
        case "$suite" in
            minimal|ubuntu|arch|powershell)
                ;;
            *)
                echo "Unknown Docker suite '$suite' for $script_path" >&2
                exit 1
                ;;
        esac
        case "$seen_suites" in
            *",$suite,"*)
                echo "Duplicate Docker suite '$suite' for $script_path" >&2
                exit 1
                ;;
        esac
        seen_suites="$seen_suites$suite,"
    done

    printf '%s\n' "$script_path" >> "$manifest_list"
done < "$MANIFEST"

LC_ALL=C sort -o "$manifest_list" "$manifest_list"

duplicates="$(uniq -d "$manifest_list")"
if [ -n "$duplicates" ]; then
    echo 'Duplicate scripts in coverage manifest:' >&2
    printf '%s\n' "$duplicates" >&2
    exit 1
fi

if ! diff -u "$actual_list" "$manifest_list"; then
    echo 'Every active home/.chezmoiscripts file must appear exactly once in tests/script-coverage.tsv.' >&2
    exit 1
fi

echo "Chezmoi script coverage manifest is complete ($(wc -l < "$actual_list" | tr -d ' ') scripts)."

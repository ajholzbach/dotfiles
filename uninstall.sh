#!/usr/bin/env sh
set -eu

DRY_RUN=0
ASSUME_YES=0
KEEP_CHEZMOI=0

usage() {
    cat <<'EOF'
Usage: uninstall.sh [--dry-run] [--yes] [--keep-chezmoi]

Restore files captured before the first dotfiles apply. The current managed
files are copied to a recovery snapshot before anything is changed.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --yes) ASSUME_YES=1 ;;
        --keep-chezmoi) KEEP_CHEZMOI=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
CURRENT_BACKUP="$STATE_ROOT/current-backup"

validate_relative_path() {
    case "$1" in
        ''|.|./*|/*|..|../*|*/../*|*/..)
            echo "Unsafe path in restore manifest: $1" >&2
            exit 1
            ;;
    esac
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | sed 's/[[:space:]].*$//'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | sed 's/[[:space:]].*$//'
    else
        return 127
    fi
}

if [ ! -e "$CURRENT_BACKUP" ] && [ ! -L "$CURRENT_BACKUP" ]; then
    echo "No dotfiles restore point was found at $CURRENT_BACKUP." >&2
    echo "Nothing was changed." >&2
    exit 1
fi

if [ ! -f "$CURRENT_BACKUP" ] || [ -L "$CURRENT_BACKUP" ] || [ ! -s "$CURRENT_BACKUP" ]; then
    echo "Invalid restore-point pointer: $CURRENT_BACKUP" >&2
    exit 1
fi

backup_id="$(sed -n '1p' "$CURRENT_BACKUP")"
case "$backup_id" in
    ''|*/*|*'..'*)
        echo "Invalid restore-point identifier: $backup_id" >&2
        exit 1
        ;;
esac

backup_dir="$STATE_ROOT/backups/$backup_id"
managed_manifest="$backup_dir/managed-files.txt"
existing_manifest="$backup_dir/existing-files.txt"

if [ ! -d "$backup_dir" ] || [ -L "$backup_dir" ] || \
        [ ! -f "$managed_manifest" ] || [ -L "$managed_manifest" ] || \
        [ ! -s "$managed_manifest" ] || \
        [ ! -f "$existing_manifest" ] || [ -L "$existing_manifest" ]; then
    echo "Restore point $backup_id is incomplete; refusing to remove managed files." >&2
    exit 1
fi

echo "Restore point: $backup_dir"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: the following managed targets would be removed or restored:"
    sed 's/^/  ~\//' "$managed_manifest"
    [ "$KEEP_CHEZMOI" -eq 1 ] || echo "  chezmoi configuration and source would be purged"
    exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    if [ ! -t 0 ]; then
        echo "Refusing a non-interactive uninstall without --yes." >&2
        exit 2
    fi
    printf 'Restore the pre-install files and remove these dotfiles? [y/N] '
    read -r answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
fi

# Validate every path before changing any of them.
while IFS= read -r relative_path; do
    validate_relative_path "$relative_path"

    target="$HOME/$relative_path"
    if [ -d "$target" ] && [ ! -L "$target" ]; then
        echo "Refusing to replace directory where a managed file was expected: $target" >&2
        exit 1
    fi

    if grep -Fqx -e "$relative_path" "$existing_manifest"; then
        original="$backup_dir/files/$relative_path"
        if [ ! -e "$original" ] && [ ! -L "$original" ]; then
            echo "Missing original file in restore point: $original" >&2
            exit 1
        fi
    fi
done < "$managed_manifest"

umask 077
snapshot_id="$(date -u '+%Y%m%dT%H%M%SZ')-$$"
snapshot_dir="$STATE_ROOT/uninstall-snapshots/$snapshot_id"
mkdir -p "$snapshot_dir/files"
: > "$snapshot_dir/current-files.txt"
printf '%s\n' "$backup_id" > "$snapshot_dir/restore-point-id"
cp -p "$managed_manifest" "$snapshot_dir/managed-files.txt"
cp -p "$existing_manifest" "$snapshot_dir/originally-existing-files.txt"

# Preserve the current managed state so post-install edits remain recoverable.
while IFS= read -r relative_path; do
    target="$HOME/$relative_path"
    if [ -e "$target" ] || [ -L "$target" ]; then
        snapshot_target="$snapshot_dir/files/$relative_path"
        mkdir -p "$(dirname "$snapshot_target")"
        cp -pP "$target" "$snapshot_target"
        printf '%s\n' "$relative_path" >> "$snapshot_dir/current-files.txt"
    fi
done < "$managed_manifest"

starship_marker="$STATE_ROOT/starship-installed-by-dotfiles"
starship_marker_valid=0
starship_path=''
recorded_starship_sha256=''
install_dir_created=''
if [ -e "$starship_marker" ] || [ -L "$starship_marker" ]; then
    if [ -f "$starship_marker" ] && [ ! -L "$starship_marker" ] && \
            [ -s "$starship_marker" ]; then
        starship_path="$(sed -n '1p' "$starship_marker")"
        recorded_starship_sha256="$(sed -n '2p' "$starship_marker")"
        install_dir_created="$(sed -n '3p' "$starship_marker")"
        marker_line_count="$(wc -l < "$starship_marker" | tr -d '[:space:]')"
        if [ "$starship_path" = "$HOME/.local/bin/starship" ] && \
                printf '%s\n' "$recorded_starship_sha256" | \
                    grep -Eq '^[0-9a-f]{64}$' && \
                { [ "$install_dir_created" = "0" ] || \
                    [ "$install_dir_created" = "1" ]; } && \
                [ "$marker_line_count" = "3" ]; then
            starship_marker_valid=1
        else
            echo "Warning: preserving Starship because its ownership marker has invalid contents." >&2
        fi
    else
        echo "Warning: preserving Starship because its ownership marker is not a non-empty regular file." >&2
    fi
fi

if [ "$starship_marker_valid" -eq 1 ]; then
    if [ -e "$starship_path" ] || [ -L "$starship_path" ]; then
        mkdir -p "$snapshot_dir/side-effects"
        cp -pP "$starship_path" "$snapshot_dir/side-effects/starship"
        cp -p "$starship_marker" "$snapshot_dir/side-effects/starship-marker"
    fi
fi

while IFS= read -r relative_path; do
    target="$HOME/$relative_path"
    rm -f "$target"

    if grep -Fqx -e "$relative_path" "$existing_manifest"; then
        original="$backup_dir/files/$relative_path"
        mkdir -p "$(dirname "$target")"
        cp -pP "$original" "$target"
        echo "Restored ~/$relative_path"
    else
        echo "Removed ~/$relative_path"
    fi
done < "$managed_manifest"

if [ "$starship_marker_valid" -eq 1 ]; then
    remove_starship=1

    if [ -e "$starship_path" ] || [ -L "$starship_path" ]; then
        if current_starship_sha256="$(sha256_file "$starship_path" 2>/dev/null)"; then
            if [ "$current_starship_sha256" != "$recorded_starship_sha256" ]; then
                remove_starship=0
                echo "Warning: preserving Starship because it changed after installation." >&2
            fi
        else
            remove_starship=0
            echo "Warning: preserving Starship because its checksum cannot be verified." >&2
        fi
    fi

    if [ "$remove_starship" -eq 1 ]; then
        rm -f "$starship_path"
        echo "Removed Starship installed by these dotfiles"
        if [ "$install_dir_created" = "1" ]; then
            rmdir "$HOME/.local/bin" 2>/dev/null || true
        fi
    fi
fi
if [ -f "$starship_marker" ] || [ -L "$starship_marker" ]; then
    rm -f "$starship_marker"
fi

printf '%s\n' "$snapshot_id" > "$STATE_ROOT/last-uninstall-snapshot"
printf '%s\n' "$backup_id" > "$STATE_ROOT/last-restored-backup"
rm -f "$CURRENT_BACKUP"
echo "Pre-uninstall files were saved to $snapshot_dir"

if [ "$KEEP_CHEZMOI" -ne 1 ] && command -v chezmoi >/dev/null 2>&1; then
    chezmoi purge --force
    echo "Purged the chezmoi source, configuration, and state."
else
    echo "Kept chezmoi metadata; use 'chezmoi purge --force' when it is no longer needed."
fi

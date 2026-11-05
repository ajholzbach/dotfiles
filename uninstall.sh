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

# Older versions saved the Fish theme to universal variables. Restore them
# before removing files, and stop if that fails.
fish_theme_restore="$STATE_ROOT/fish-theme-restore.fish"
fish_frozen_theme_restore="$STATE_ROOT/fish-frozen-theme-restore.fish"
if [ -f "$fish_theme_restore" ]; then
    fish_variables="$HOME/.config/fish/fish_variables"
    [ ! -f "$fish_variables" ] || cp -p "$fish_variables" "$snapshot_dir/fish_variables"
    # $argv is a Fish variable.
    # shellcheck disable=SC2016
    if ! command -v fish >/dev/null 2>&1 || \
            ! DOTFILES_LOADING_LOCAL_ENV=1 XDG_CONFIG_HOME="$HOME/.config" \
                fish -c 'source $argv[1]' "$fish_theme_restore" >/dev/null 2>&1; then
        echo "Error: the old Fish theme state could not be restored. Install or repair Fish, then rerun this command." >&2
        exit 1
    fi
    if [ -f "$fish_frozen_theme_restore" ]; then
        mkdir -p "$HOME/.config/fish/conf.d"
        cp -p "$fish_frozen_theme_restore" "$HOME/.config/fish/conf.d/fish_frozen_theme.fish"
    fi
    rm -f "$fish_theme_restore" "$fish_frozen_theme_restore" \
        "$STATE_ROOT/fish-theme-applied-by-dotfiles"
    echo "Restored the Fish colors from before these dotfiles"
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

# Remove Starship and Antidote only when they are still exactly as the
# dotfiles installed them. Older markers also hold other lines.
starship_marker="$STATE_ROOT/starship-installed-by-dotfiles"
starship_path="$HOME/.local/bin/starship"
if [ -f "$starship_marker" ]; then
    recorded="$(grep -Em 1 '^[0-9a-f]{64}$' "$starship_marker" || true)"
    current="$({ sha256sum "$starship_path" 2>/dev/null || shasum -a 256 "$starship_path" 2>/dev/null; } | cut -d ' ' -f 1)"
    if [ -n "$recorded" ] && [ "$recorded" = "$current" ]; then
        rm -f "$starship_path"
        echo "Removed Starship installed by these dotfiles"
    elif [ -e "$starship_path" ]; then
        echo "Warning: preserving Starship because it changed after installation." >&2
    fi
    rm -f "$starship_marker"
fi

antidote_marker="$STATE_ROOT/antidote-installed-by-dotfiles"
antidote_path="$HOME/.antidote"
if [ -f "$antidote_marker" ]; then
    recorded="$(grep -Em 1 '^[0-9a-f]{40,64}$' "$antidote_marker" || true)"
    if [ -n "$recorded" ] && [ -d "$antidote_path" ] && [ ! -L "$antidote_path" ] && \
            [ "$(git -C "$antidote_path" rev-parse HEAD 2>/dev/null)" = "$recorded" ] && \
            [ -z "$(git -C "$antidote_path" status --porcelain --untracked-files=all 2>&1)" ]; then
        rm -rf "$antidote_path"
        echo "Removed Antidote installed by these dotfiles"
    elif [ -e "$antidote_path" ]; then
        echo "Warning: preserving Antidote because its checkout changed or could not be verified." >&2
    fi
    rm -f "$antidote_marker"
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

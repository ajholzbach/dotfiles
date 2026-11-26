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

# A broken symlink also counts as present
path_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

if ! path_exists "$CURRENT_BACKUP"; then
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

existed_before_install() {
    grep -Fqx -e "$1" "$existing_manifest"
}

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

# A bad manifest must stop the uninstall before any file changes
while IFS= read -r relative_path; do
    validate_relative_path "$relative_path"

    target="$HOME/$relative_path"
    if [ -d "$target" ] && [ ! -L "$target" ]; then
        echo "Refusing to replace directory where a managed file was expected: $target" >&2
        exit 1
    fi

    if existed_before_install "$relative_path"; then
        original="$backup_dir/files/$relative_path"
        if ! path_exists "$original"; then
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

# Edits made after install must stay recoverable
while IFS= read -r relative_path; do
    target="$HOME/$relative_path"
    if path_exists "$target"; then
        snapshot_target="$snapshot_dir/files/$relative_path"
        mkdir -p "$(dirname "$snapshot_target")"
        cp -pP "$target" "$snapshot_target"
        printf '%s\n' "$relative_path" >> "$snapshot_dir/current-files.txt"
    fi
done < "$managed_manifest"

# DOTFILES_LOADING_LOCAL_ENV=1 keeps config.fish from sourcing local-env.fish
restore_fish_universals() {
    # shellcheck disable=SC2016 # Fish expands $argv
    if ! command -v fish >/dev/null 2>&1 || \
            ! DOTFILES_LOADING_LOCAL_ENV=1 XDG_CONFIG_HOME="$HOME/.config" \
                fish -c 'source $argv[1]' "$1" >/dev/null 2>&1; then
        echo "Error: the old Fish state could not be restored. Install or repair Fish, then rerun this command." >&2
        exit 1
    fi
}

# The colors of the older theme save must win
# Both restores run before the managed files are removed
fish_universals_restore="$STATE_ROOT/fish-universals-restore.fish"
fish_theme_restore="$STATE_ROOT/fish-theme-restore.fish"
fish_frozen_theme_restore="$STATE_ROOT/fish-frozen-theme-restore.fish"
fish_variables="$HOME/.config/fish/fish_variables"
if [ -f "$fish_variables" ] && { [ -f "$fish_universals_restore" ] || [ -f "$fish_theme_restore" ]; }; then
    cp -p "$fish_variables" "$snapshot_dir/fish_variables"
fi
if [ -f "$fish_universals_restore" ]; then
    restore_fish_universals "$fish_universals_restore"
    rm -f "$fish_universals_restore"
    echo "Restored the Fish universal variables from before these dotfiles"
fi
# Older versions saved the Fish theme to universal variables
if [ -f "$fish_theme_restore" ]; then
    restore_fish_universals "$fish_theme_restore"
    if [ -f "$fish_frozen_theme_restore" ]; then
        mkdir -p "$HOME/.config/fish/conf.d"
        cp -p "$fish_frozen_theme_restore" "$HOME/.config/fish/conf.d/fish_frozen_theme.fish"
    fi
    rm -f "$fish_theme_restore" "$fish_frozen_theme_restore" \
        "$STATE_ROOT/fish-theme-applied-by-dotfiles"
    echo "Restored the Fish colors from before these dotfiles"
fi

# The Fish cleanup script moved these files aside
fish_files_backup="$STATE_ROOT/fish-files-backup"
if [ -d "$fish_files_backup" ]; then
    (cd "$fish_files_backup" && find . ! -type d) | while IFS= read -r relative_path; do
        relative_path="${relative_path#./}"
        validate_relative_path "$relative_path"
        target="$HOME/.config/fish/$relative_path"
        if path_exists "$target"; then
            continue
        fi
        mkdir -p "$(dirname "$target")"
        cp -pP "$fish_files_backup/$relative_path" "$target"
        echo "Restored ~/.config/fish/$relative_path"
    done
    rm -rf "$fish_files_backup"
fi

while IFS= read -r relative_path; do
    target="$HOME/$relative_path"
    rm -f "$target"

    if existed_before_install "$relative_path"; then
        mkdir -p "$(dirname "$target")"
        cp -pP "$backup_dir/files/$relative_path" "$target"
        echo "Restored ~/$relative_path"
    else
        echo "Removed ~/$relative_path"
    fi
done < "$managed_manifest"

# Remove Starship and Antidote only when they did not change after install
starship_marker="$STATE_ROOT/starship-installed-by-dotfiles"
starship_path="$HOME/.local/bin/starship"
if [ -f "$starship_marker" ]; then
    # Older markers hold other lines too
    recorded_checksum="$(grep -Em 1 '^[0-9a-f]{64}$' "$starship_marker" || true)"
    current_checksum="$({ sha256sum "$starship_path" 2>/dev/null || shasum -a 256 "$starship_path" 2>/dev/null; } | cut -d ' ' -f 1)"
    if [ -n "$recorded_checksum" ] && [ "$recorded_checksum" = "$current_checksum" ]; then
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
    recorded_commit="$(grep -Em 1 '^[0-9a-f]{40,64}$' "$antidote_marker" || true)"
    if [ -n "$recorded_commit" ] && [ -d "$antidote_path" ] && [ ! -L "$antidote_path" ] && \
            [ "$(git -C "$antidote_path" rev-parse HEAD 2>/dev/null)" = "$recorded_commit" ] && \
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

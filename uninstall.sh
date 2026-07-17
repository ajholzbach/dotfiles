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

antidote_marker="$STATE_ROOT/antidote-installed-by-dotfiles"
antidote_marker_valid=0
antidote_path=''
recorded_antidote_commit=''
if [ -e "$antidote_marker" ] || [ -L "$antidote_marker" ]; then
    if [ -f "$antidote_marker" ] && [ ! -L "$antidote_marker" ] && \
            [ "$(wc -l < "$antidote_marker" | tr -d '[:space:]')" = "2" ]; then
        antidote_path="$(sed -n '1p' "$antidote_marker")"
        recorded_antidote_commit="$(sed -n '2p' "$antidote_marker")"
        if [ "$antidote_path" = "$HOME/.antidote" ] && \
                printf '%s\n' "$recorded_antidote_commit" | \
                    grep -Eq '^[0-9a-f]{40,64}$'; then
            antidote_marker_valid=1
        else
            echo "Warning: preserving Antidote because its ownership marker has invalid contents." >&2
        fi
    else
        echo "Warning: preserving Antidote because its ownership marker is not a two-line regular file." >&2
    fi
fi

fish_theme_marker="$STATE_ROOT/fish-theme-applied-by-dotfiles"
fish_theme_restore="$STATE_ROOT/fish-theme-restore.fish"
fish_frozen_theme="$HOME/.config/fish/conf.d/fish_frozen_theme.fish"
fish_frozen_theme_restore="$STATE_ROOT/fish-frozen-theme-restore.fish"
fish_theme_marker_valid=0
fish_theme_state_present=0
if [ -e "$fish_theme_marker" ] || [ -L "$fish_theme_marker" ] || \
        [ -e "$fish_theme_restore" ] || [ -L "$fish_theme_restore" ] || \
        [ -e "$fish_frozen_theme_restore" ] || [ -L "$fish_frozen_theme_restore" ]; then
    fish_theme_state_present=1
    if [ -f "$fish_theme_marker" ] && [ ! -L "$fish_theme_marker" ] && \
            [ "$(wc -l < "$fish_theme_marker" | tr -d '[:space:]')" = "3" ] && \
            [ -f "$fish_theme_restore" ] && [ ! -L "$fish_theme_restore" ]; then
        recorded_theme_sha256="$(sed -n '1p' "$fish_theme_marker")"
        recorded_restore_sha256="$(sed -n '2p' "$fish_theme_marker")"
        recorded_frozen_state="$(sed -n '3p' "$fish_theme_marker")"
        if printf '%s\n' "$recorded_theme_sha256" | grep -Eq '^[0-9a-f]{64}$' && \
                printf '%s\n' "$recorded_restore_sha256" | grep -Eq '^[0-9a-f]{64}$' && \
                current_restore_sha256="$(sha256_file "$fish_theme_restore" 2>/dev/null)" && \
                [ "$current_restore_sha256" = "$recorded_restore_sha256" ]; then
            case "$recorded_frozen_state" in
                absent)
                    if [ ! -e "$fish_frozen_theme_restore" ] && \
                            [ ! -L "$fish_frozen_theme_restore" ]; then
                        fish_theme_marker_valid=1
                    fi
                    ;;
                *)
                    if printf '%s\n' "$recorded_frozen_state" | \
                            grep -Eq '^[0-9a-f]{64}$' && \
                            [ -f "$fish_frozen_theme_restore" ] && \
                            [ ! -L "$fish_frozen_theme_restore" ] && \
                            [ "$recorded_frozen_state" = \
                                "$(sha256_file "$fish_frozen_theme_restore" 2>/dev/null)" ]; then
                        fish_theme_marker_valid=1
                    fi
                    ;;
            esac
            if [ "$fish_theme_marker_valid" -ne 1 ]; then
                echo "Warning: preserving Fish theme state because its frozen-theme restore data is invalid." >&2
            fi
        else
            echo "Warning: preserving Fish theme state because its ownership data is invalid or changed." >&2
        fi
    else
        echo "Warning: preserving Fish theme state because its marker or restore script is unsafe." >&2
    fi
fi

if [ "$fish_theme_marker_valid" -eq 1 ] && \
        [ -d "$fish_frozen_theme" ] && [ ! -L "$fish_frozen_theme" ]; then
    fish_theme_marker_valid=0
    echo "Warning: preserving Fish theme state because the frozen-theme target is now a directory." >&2
fi

if [ "$fish_theme_state_present" -eq 1 ] && \
        [ "$fish_theme_marker_valid" -ne 1 ]; then
    echo "Error: Fish theme restore state is unsafe; refusing to continue uninstall." >&2
    echo "Repair or remove that state explicitly, then rerun this command." >&2
    exit 1
fi

if [ "$starship_marker_valid" -eq 1 ]; then
    if [ -e "$starship_path" ] || [ -L "$starship_path" ]; then
        mkdir -p "$snapshot_dir/side-effects"
        cp -pP "$starship_path" "$snapshot_dir/side-effects/starship"
        cp -p "$starship_marker" "$snapshot_dir/side-effects/starship-marker"
    fi
fi

if [ "$antidote_marker_valid" -eq 1 ]; then
    mkdir -p "$snapshot_dir/side-effects"
    cp -p "$antidote_marker" "$snapshot_dir/side-effects/antidote-marker"
    if [ -d "$antidote_path" ] && [ ! -L "$antidote_path" ]; then
        cp -pPR "$antidote_path" "$snapshot_dir/side-effects/antidote"
    fi
fi

if [ "$fish_theme_marker_valid" -eq 1 ]; then
    mkdir -p "$snapshot_dir/side-effects"
    cp -p "$fish_theme_marker" "$snapshot_dir/side-effects/fish-theme-marker"
    cp -p "$fish_theme_restore" "$snapshot_dir/side-effects/fish-theme-restore.fish"
    if [ -f "$fish_frozen_theme_restore" ] && [ ! -L "$fish_frozen_theme_restore" ]; then
        cp -p "$fish_frozen_theme_restore" \
            "$snapshot_dir/side-effects/fish-frozen-theme-restore.fish"
    fi
    if [ -e "$fish_frozen_theme" ] || [ -L "$fish_frozen_theme" ]; then
        cp -pP "$fish_frozen_theme" \
            "$snapshot_dir/side-effects/fish-frozen-theme-current.fish"
    fi
    fish_variables="$HOME/.config/fish/fish_variables"
    if [ -f "$fish_variables" ] && [ ! -L "$fish_variables" ]; then
        cp -p "$fish_variables" "$snapshot_dir/side-effects/fish_variables"
    fi
fi

if [ "$fish_theme_marker_valid" -eq 1 ]; then
    fish_theme_restored=0
    if command -v fish >/dev/null 2>&1 && \
            DOTFILES_LOADING_LOCAL_ENV=1 XDG_CONFIG_HOME="$HOME/.config" \
                fish -c 'source "$argv[1]"; or exit 1; exit 0' \
                "$fish_theme_restore" >/dev/null 2>&1; then
        case "$recorded_frozen_state" in
            absent)
                rm -f "$fish_frozen_theme"
                fish_theme_restored=1
                ;;
            *)
                frozen_theme_target_tmp="${fish_frozen_theme}.dotfiles-restore.$$"
                if mkdir -p "$(dirname "$fish_frozen_theme")" && \
                        cp -p "$fish_frozen_theme_restore" "$frozen_theme_target_tmp" && \
                        mv "$frozen_theme_target_tmp" "$fish_frozen_theme"; then
                    fish_theme_restored=1
                else
                    rm -f "$frozen_theme_target_tmp"
                fi
                ;;
        esac
    fi

    if [ "$fish_theme_restored" -eq 1 ]; then
        rm -f "$fish_theme_marker" "$fish_theme_restore" \
            "$fish_frozen_theme_restore"
        echo "Restored the Fish theme state from before these dotfiles"
    else
        echo "Error: Fish theme restore state could not be applied; refusing to continue uninstall." >&2
        echo "Install or repair Fish, then rerun this command." >&2
        exit 1
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

if [ "$antidote_marker_valid" -eq 1 ]; then
    remove_antidote=1
    if [ -e "$antidote_path" ] || [ -L "$antidote_path" ]; then
        if [ ! -d "$antidote_path" ] || [ -L "$antidote_path" ] || \
                ! command -v git >/dev/null 2>&1; then
            remove_antidote=0
        else
            current_antidote_commit="$(git -C "$antidote_path" rev-parse --verify HEAD 2>/dev/null || true)"
            current_antidote_origin="$(git -C "$antidote_path" config --get remote.origin.url 2>/dev/null || true)"
            current_antidote_changes="$(git -C "$antidote_path" status --porcelain --untracked-files=all 2>/dev/null || printf '%s' invalid)"
            if [ "$current_antidote_commit" != "$recorded_antidote_commit" ] || \
                    [ "$current_antidote_origin" != "https://github.com/mattmc3/antidote.git" ] || \
                    [ -n "$current_antidote_changes" ]; then
                remove_antidote=0
            fi
        fi
    fi

    if [ "$remove_antidote" -eq 1 ]; then
        rm -rf "$antidote_path"
        echo "Removed Antidote installed by these dotfiles"
    else
        echo "Warning: preserving Antidote because its checkout changed or could not be verified." >&2
    fi
fi
if [ -f "$antidote_marker" ] || [ -L "$antidote_marker" ]; then
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

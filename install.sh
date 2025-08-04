#!/bin/bash
set -e # Exit on error

# Dynamically determine the dotfiles repo location
DOTFILES_REPO=$(dirname "$(realpath "$0")")

# Source the dotfiles configuration
source "$DOTFILES_REPO/dotfiles"

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help       Show this help message and exit"
    echo "  -r, --restore    Remove dotfiles and restore backups"
}

# Parse arguments
RESTORE_BACKUPS=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--restore)
            RESTORE_BACKUPS=true
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# Function to install file
install_file() {
    local file=$1
    local target="$HOME/$file"
    local source="$DOTFILES_REPO/$file"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target")"

    # Check if target exists and backup if needed
    if [ -L "$target" ]; then
        echo "Removing existing symlink $file"
        rm "$target"
    elif [ -e "$target" ]; then
        local backup="${target}.bak"
        
        # Handle directory backups specially
        if [ -d "$target" ]; then
            if [ -d "$backup" ]; then
                echo "Removing existing backup directory $backup"
                rm -rf "$backup"
            fi
        fi
        
        echo "Backing up existing $file to $file.bak"
        mv "$target" "$backup"
    fi

    # Copy file/directory
    if [ -d "$source" ]; then
        cp -r "$source" "$target"
    else
        cp "$source" "$target"
    fi
    
    echo "Installed $file"
}

restore_file() {
    local file=$1
    local target="$HOME/$file"
    local backup="${target}.bak"

    # Remove current file/directory if it exists
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo "Removing $file"
        rm -rf "$target"
    fi

    # Restore backup if it exists
    if [ -e "$backup" ]; then
        echo "Restoring backup for $file"
        mv "$backup" "$target"
    else
        echo "Warning: No backup found for $file"
    fi
}

# Check for required commands
for cmd in git curl; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

# Install Oh My Zsh if not installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Oh My Zsh plugins
for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
    if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]; then
        echo "Installing $plugin plugin..."
        git clone "https://github.com/zsh-users/$plugin.git" "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/$plugin"
    fi
done

# Install Powerlevel10k if not installed
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
fi

# Install Catppuccin Mocha theme for vim if not installed
if [ ! -f "$HOME/.vim/colors/catppuccin_mocha.vim" ]; then
    echo "Installing Catppuccin Mocha theme for vim..."
    mkdir -p "$HOME/.vim/colors"
    cp "$DOTFILES_REPO/catppuccin/catppuccin_mocha.vim" "$HOME/.vim/colors/"
fi

# Install dotfiles or restore backups
if [ "$RESTORE_BACKUPS" = true ]; then
    for file in "${DOTFILES[@]}"; do
        restore_file "$file"
    done
    echo "Dotfiles restored successfully!"
    exit 0
fi

# Install dotfiles
for file in "${DOTFILES[@]}"; do
    install_file "$file"
done

# Configure global gitignore
git config --global core.excludesfile ~/.gitignore_global

echo "Dotfiles installation complete!"

if command_exists bat; then
    echo "Building bat cache..."
    bat cache --build
fi

# Switch to fish or zsh
if command_exists fish; then
    exec fish -l
elif command_exists zsh; then
    exec zsh -l
fi

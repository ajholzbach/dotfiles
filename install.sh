#!/bin/bash
set -e # Exit on error

# Dotfiles paths (relative to the dotfiles repo)
# Add any new dotfiles here to track them
DOTFILES=(".vimrc" ".zshrc" ".p10k.zsh" ".gitignore_global" ".condarc" ".config/zed" ".config/bat" ".config/btop" ".config/thefuck" ".config/lazygit")

# Dynamically determine the dotfiles repo location
DOTFILES_REPO=$(dirname "$(realpath "$0")")
echo "Dotfiles repository located at: $DOTFILES_REPO"

# Function to check if a command exists
command_exists () {
    type "$1" &> /dev/null ;
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help       Show this help message and exit"
    echo "  -l, --link       Create symlinks for dotfiles"
    echo "  -r, --restore    Remove symlinks and restore backups"
}

# Parse arguments
CREATE_SYMLINKS=false
RESTORE_BACKUPS=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--link)
            CREATE_SYMLINKS=true
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

# Function to install file (create symlink or copy)
install_file() {
    local file=$1
    local target="$HOME/$file"
    local source="$DOTFILES_REPO/$file"

    # Ensure parent directory exists for the target (but avoid creating the target directory itself)
    mkdir -p "$(dirname "$target")"

    # Check if the target is a symlink
    if [ -L "$target" ]; then
        echo "$file symlink already exists. Replacing symlink..."
        rm -v "$target"  # Remove the existing symlink
    elif [ -e "$target" ]; then
        # Backup existing file or directory if it's not a symlink
        echo "Backing up existing $file to $file.bak"
        mv -v "$target" "${target}.bak"
    fi

    # Create symlink or copy file/directory
    if [ "$CREATE_SYMLINKS" = true ]; then
        # Symlink the file or directory
        ln -sv "$source" "$target"
    else
        # If it's a directory, copy recursively; otherwise, copy the file
        if [ -d "$source" ]; then
            cp -rv "$source" "$target"
        else
            cp -v "$source" "$target"
        fi
    fi
}

restore_file() {
    local file=$1
    local target="$HOME/$file"

    # Remove symlink if it exists
    if [ -L "$target" ]; then
        echo "Removing symlink $file"
        rm -v "$target"
    elif [ -e "$target" ]; then
        # If it's not a symlink but still exists, remove it
        echo "$file exists but is not a symlink. Removing it before restoring backup."
        rm -rv "$target"
    fi

    # Restore backup if it exists
    if [ -e "${target}.bak" ]; then
        echo "Restoring backup for $file"
        mv -v "${target}.bak" "$target"
        cp -rv "$target" "${target}.bak"  # Backup the restored file
    else
        echo "Warning: No backup found for $file"
    fi
}

# Check for required commands
for cmd in git curl mkdir; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

# Install Oh My Zsh if not installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh already installed"
fi

# Install Oh My Zsh plugins
echo "Installing Oh My Zsh plugins..."
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting plugin already installed"
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions plugin already installed"
fi

# Install Powerlevel10k if not installed
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
else
    echo "Powerlevel10k theme already installed"
fi

# Install Catppuccin Mocha theme for vim if not installed
if [ ! -f "$HOME/.vim/colors/catppuccin_mocha.vim" ]; then
    echo "Installing Catppuccin Mocha theme for vim..."
    mkdir -p $HOME/.vim/colors
    cp $DOTFILES_REPO/catppuccin/catppuccin_mocha.vim $HOME/.vim/colors/
else
    echo "Catppuccin Mocha theme for vim already installed"
fi

# Install dotfiles or restore backups
if [[ "$RESTORE_BACKUPS" == true ]]; then
    echo "Restoring backups..."
    # Run restore_file for each dotfile
    for file in "${DOTFILES[@]}"; do
        restore_file "$file"
    done
    echo "Backups restored"
    exit 0
else
    echo "Installing dotfiles..."
    # Run install_file for each dotfile
    for file in "${DOTFILES[@]}"; do
        install_file "$file"
    done
fi

# Configure global gitignore
git config --global core.excludesfile ~/.gitignore_global

echo "Dotfiles installation complete!"

if command_exists zsh; then
    echo "Changing shell to zsh..."
    exec zsh -l
else
    echo "Zsh is not installed. Staying with the current shell."
fi

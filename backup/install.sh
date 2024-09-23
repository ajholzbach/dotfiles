#!/bin/bash
set -e # Exit on error

# Dynamically determine the dotfiles repo location
DOTFILES_REPO=$(dirname "$(realpath "$0")")
echo "Dotfiles repository located at: $DOTFILES_REPO"

# Parse arguments for "-l" option
CREATE_SYMLINKS=false

while getopts ":l" opt; do
  case ${opt} in
    l ) CREATE_SYMLINKS=true ;;
    \? ) echo "Usage: cmd [-l]" ;;
  esac
done

# Install Oh My Zsh if not installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh already installed."
fi

# Install Oh My Zsh plugins
echo "Installing Oh My Zsh plugins..."
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting plugin already installed."
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions plugin already installed."
fi

# Install Powerlevel10k if not installed
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
else
    echo "Powerlevel10k theme already installed."
fi

# Install Catppuccin Mocha theme for vim if not installed
if [ ! -f "$HOME/.vim/colors/catppuccin_mocha.vim" ]; then
    echo "Installing Catppuccin Mocha theme for vim..."
    mkdir -p $HOME/.vim/colors
    cp ./dotfiles/catppuccin/catppuccin_mocha.vim $HOME/.vim/colors/
else
    echo "Catppuccin Mocha theme for vim already installed."
fi

# Function to handle file (create symlink or copy)
handle_file() {
    local file=$1
    local target="$HOME/$file"
    local source="$DOTFILES_REPO/$file"

    # Check if the target is a symlink
    if [ -L "$target" ]; then
        echo "$file symlink already exists. Skipping..."
        return
    fi

    # Backup existing file
    if [ -e "$target" ]; then
        echo "Backing up existing $file to $file.bak"
        mv -v "$target" "${target}.bak"
    fi

    # Create symlink or copy file
    if [ "$CREATE_SYMLINKS" = true ]; then
        ln -sfv "$source" "$target"
    else
        cp -v "$source" "$target"
    fi
}

echo "Setting up dotfiles..."

# Handle each file
handle_file ".zshrc"
handle_file ".p10k.zsh"
handle_file ".vimrc"
handle_file ".gitignore_global"
# Add more files as needed

# Configure global gitignore
git config --global core.excludesfile ~/.gitignore_global

echo "Dotfiles installation complete!"

if command_exists zsh; then
    echo "Changing shell to zsh..."
    exec zsh -l
else
    echo "Zsh is not installed. Staying with the current shell."
fi

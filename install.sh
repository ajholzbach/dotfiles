#!/bin/bash
set -v # Verbose mode
set -e # Exit on error

# Dynamically determine the dotfiles repo location
DOTFILES_REPO=$(dirname "$(realpath "$0")")

# Function to check if a command exists
command_exists () {
    type "$1" &> /dev/null ;
}

# Detecting the platform and package manager
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command_exists apt-get ; then
        sudo apt-get update
        sudo apt-get install git vim -y
    elif command_exists yum ; then
        sudo yum install git vim -y
    elif command_exists pacman ; then
        sudo pacman -Sy git vim
    elif command_exists zypper ; then
        sudo zypper install git vim
    else
        echo "No recognized package manager found. Install git and vim manually."
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install git vim
fi

# Install Oh My Zsh if not installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install Oh My Zsh plugins
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" ]; then
    git clone https://github.com/zsh-users/zsh-completions $HOME/.oh-my-zsh/custom/plugins/zsh-completions
fi

# Install Powerlevel10k if not installed
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
fi

# Creating symlinks
ln -sfv "$DOTFILES_REPO/.zshrc" ~/
ln -sfv "$DOTFILES_REP/.p10k.zsh" ~/
# Add more symlinks as needed

echo "Dotfiles installation complete!"


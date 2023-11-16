#!/bin/bash
set -e # Exit on error

# Dynamically determine the dotfiles repo location
DOTFILES_REPO=$(dirname "$(realpath "$0")")
echo "Dotfiles repository located at: $DOTFILES_REPO"

# Function to check if a command exists
command_exists () {
    type "$1" &> /dev/null ;
}

# Flag for installing sudo-required packages
INSTALL_SUDO_PACKAGES=false

while getopts ":s" opt; do
  case ${opt} in
    s ) INSTALL_SUDO_PACKAGES=true
    ;;
    \? ) echo "Usage: cmd [-s]"
    ;;
  esac
done

# Detecting the platform and package manager
if [[ "$INSTALL_SUDO_PACKAGES" == true ]]; then
    echo "Installing sudo-required packages..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt ; then
            sudo apt update
            sudo apt install vim -y
        elif command_exists yum ; then
            sudo yum install vim -y
        elif command_exists pacman ; then
            sudo pacman -Sy vim
        elif command_exists zypper ; then
            sudo zypper install vim
        else
            echo "No recognized package manager found. Install vim manually."
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install vim
    fi
else
    echo "Skipping installation of sudo-required packages."
fi

# Install Oh My Zsh if not installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed."
fi

# Install Oh My Zsh plugins
echo "Installing Oh My Zsh plugins..."
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

# Install Powerlevel10k if not installed
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
else
    echo "Powerlevel10k theme already installed."
fi

# Creating symlinks
echo "Creating symlinks for dotfiles..."
ln -sfv "$DOTFILES_REPO/.zshrc" ~/
ln -sfv "$DOTFILES_REPO/.p10k.zsh" ~/
# Add more symlinks as needed

echo "Dotfiles installation complete!"

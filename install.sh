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

# List of packages to install
PACKAGES_TO_INSTALL=("vim" "neofetch" "wget")
PACKAGES_TO_INSTALL_STRING="${PACKAGES_TO_INSTALL[@]}"

# Detecting the platform and package manager
if [[ "$INSTALL_SUDO_PACKAGES" == true ]]; then
    echo "Installing sudo-required packages..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt ; then
            sudo apt update -y
            sudo apt install $PACKAGES_TO_INSTALL_STRING -y
        elif command_exists dnf ; then
            sudo dnf update -y
            sudo dnf install $PACKAGES_TO_INSTALL_STRING -y
        elif command_exists yum ; then
            sudo yum update -y
            sudo yum install $PACKAGES_TO_INSTALL_STRING -y
        elif command_exists pacman ; then
            sudo pacman -Sy
            sudo pacman -S $PACKAGES_TO_INSTALL_STRING --noconfirm
        elif command_exists zypper ; then
            sudo zypper refresh
            sudo zypper install $PACKAGES_TO_INSTALL_STRING -y
        elif command_exists apk ; then
            sudo apk update
            sudo apk add $PACKAGES_TO_INSTALL_STRING
        elif command_exists emerge ; then
            sudo emerge --sync
            sudo emerge $PACKAGES_TO_INSTALL_STRING
        else
            echo "No recognized package manager found. Install vim manually."
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew update
        brew install $PACKAGES_TO_INSTALL_STRING
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

# Install Dracula theme for vim if not installed
if [ ! -d "$HOME/.vim/pack/themes/start/dracula" ]; then
    echo "Installing Dracula theme for vim..."
    mkdir -p $HOME/.vim/pack/themes/start
    git clone https://github.com/dracula/vim.git $HOME/.vim/pack/themes/start/dracula
else
    echo "Dracula theme for vim already installed."
fi

# Creating symlinks
echo "Creating symlinks for dotfiles..."

# Check and create symlink for .zshrc
if [ ! -L "$HOME/.zshrc" ]; then
    ln -sfv "$DOTFILES_REPO/.zshrc" ~/
else
    echo ".zshrc symlink already exists."
fi

# Check and create symlink for .p10k.zsh
if [ ! -L "$HOME/.p10k.zsh" ]; then
    ln -sfv "$DOTFILES_REPO/.p10k.zsh" ~/
else
    echo ".p10k.zsh symlink already exists."
fi

# Check and create symlink for .vimrc
if [ ! -L "$HOME/.vimrc" ]; then
    ln -sfv "$DOTFILES_REPO/.vimrc" ~/
else
    echo ".vimrc symlink already exists."
fi

# Add more checks and symlinks as needed

echo "Dotfiles installation complete!"

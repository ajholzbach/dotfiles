#!/bin/bash
set -e # Exit on error

# Dynamically determine the dotfiles repo location
DOTFILES_REPO=$(dirname "$(realpath "$0")")
echo "Dotfiles repository located at: $DOTFILES_REPO"

# Function to check if a command exists
command_exists () {
    type "$1" &> /dev/null ;
}

# Parse arguments for "-l" and "-s" options
CREATE_SYMLINKS=false
INSTALL_PACKAGES=false

while getopts ":ls" opt; do
  case ${opt} in
    l ) CREATE_SYMLINKS=true ;;
    s ) INSTALL_PACKAGES=true ;;
    \? ) echo "Usage: cmd [-l] [-s]" ;;
  esac
done

# List of packages to install
PACKAGES_TO_INSTALL=("vim" "neofetch" "wget")
PACKAGES_TO_INSTALL_STRING="${PACKAGES_TO_INSTALL[@]}"

# Detecting the platform and package manager
if [[ "$INSTALL_PACKAGES" == true ]]; then
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

    # Install SDKMAN if not installed
    if [ ! -d "$HOME/.sdkman" ]; then
        echo "Installing SDKMAN..."
        curl -s "https://get.sdkman.io" | bash
        # Initialize SDKMAN
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    else
        echo "SDKMAN already installed."
    fi

else
    echo "Skipping installation of sudo-required packages."
fi

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

# Install Dracula theme for vim if not installed
if [ ! -d "$HOME/.vim/pack/themes/start/dracula" ]; then
    echo "Installing Dracula theme for vim..."
    mkdir -p $HOME/.vim/pack/themes/start
    git clone https://github.com/dracula/vim.git $HOME/.vim/pack/themes/start/dracula
else
    echo "Dracula theme for vim already installed."
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

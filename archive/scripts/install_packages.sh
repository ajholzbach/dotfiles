#!/bin/bash
set -e

command_exists () {
    type "$1" &> /dev/null ;
}

PACKAGES_TO_INSTALL=("vim" "neofetch" "wget")
PACKAGES_TO_INSTALL_STRING="${PACKAGES_TO_INSTALL[@]}"

echo "Installing packages..."
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
        echo "No recognized package manager found. Install packages manually."
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew update
    brew install $PACKAGES_TO_INSTALL_STRING
fi

if [ ! -d "$HOME/.sdkman" ]; then
    echo "Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
else
    echo "SDKMAN already installed."
fi

#!/bin/bash
set -e # Exit on error

# List of casks to install
casks=(
    alt-tab
    git-credential-manager
    mactex-no-gui
    spotify
    xquartz
    appcleaner
    google-chrome
    miniconda
    standard-notes
    darktable
    hiddenbar
    prismlauncher
    stats
    discord
    iina
    raycast
    steam
    firefox
    iterm2
    rectangle
    visual-studio-code
)

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Install casks
echo "Installing casks..."
for cask in "${casks[@]}"; do
    brew install --cask "$cask"
done

echo "Cask installation completed."

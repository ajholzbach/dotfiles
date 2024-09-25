#!/bin/bash
set -e # Exit on error

# Array of font URLs and names
FONT_URLS=(
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
)
FONT_NAMES=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
)

# Function to check if a command exists
command_exists() {
    type "$1" &> /dev/null
}

# Function to install fonts on macOS
install_fonts_mac() {
    echo "Installing fonts on macOS..."
    FONT_DIR=~/Library/Fonts

    # Create the font directory if it doesn't exist
    mkdir -p "$FONT_DIR"

    # Download and move the font files
    for i in "${!FONT_URLS[@]}"; do
        curl -L -o "$FONT_DIR/${FONT_NAMES[$i]}" "${FONT_URLS[$i]}" || {
            echo "Failed to download ${FONT_NAMES[$i]}"
            exit 1
        }
    done

    echo "Fonts installed successfully in $FONT_DIR."
}

# Function to install fonts on Linux
install_fonts_linux() {
    echo "Installing fonts on Linux..."
    FONT_DIR=~/.local/share/fonts

    # Create the font directory if it doesn't exist
    mkdir -p "$FONT_DIR"

    # Download and move the font files
    for i in "${!FONT_URLS[@]}"; do
        curl -L -o "$FONT_DIR/${FONT_NAMES[$i]}" "${FONT_URLS[$i]}" || {
            echo "Failed to download ${FONT_NAMES[$i]}"
            exit 1
        }
    done

    # Update font cache
    fc-cache -f -v

    echo "Fonts installed successfully in $FONT_DIR."
}

# Determine the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    install_fonts_mac
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    install_fonts_linux
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

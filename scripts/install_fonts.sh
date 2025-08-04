#!/bin/bash
set -e

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

install_fonts_mac() {
    echo "Installing fonts on macOS..."
    FONT_DIR="$HOME/Library/Fonts"

    mkdir -p "$FONT_DIR"

    for i in "${!FONT_URLS[@]}"; do
        curl -L -o "$FONT_DIR/${FONT_NAMES[$i]}" "${FONT_URLS[$i]}" || {
            echo "Failed to download ${FONT_NAMES[$i]}"
            exit 1
        }
    done

    echo "Fonts installed successfully in $FONT_DIR."
}

install_fonts_linux() {
    echo "Installing fonts on Linux..."
    FONT_DIR="$HOME/.local/share/fonts"

    mkdir -p "$FONT_DIR"

    for i in "${!FONT_URLS[@]}"; do
        curl -L -o "$FONT_DIR/${FONT_NAMES[$i]}" "${FONT_URLS[$i]}" || {
            echo "Failed to download ${FONT_NAMES[$i]}"
            exit 1
        }
    done

    fc-cache -f -v

    echo "Fonts installed successfully in $FONT_DIR."
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    install_fonts_mac
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    install_fonts_linux
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

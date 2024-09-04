# dotfiles
A repo to store my dotfiles + a comprehensive install script

## Contents
- `install.sh`: Installs dotfiles and other packages (if specified)
- `.zshrc`: Zsh config
- `.vimrc`: Vim config
- `.p10k.zsh`: Powerlevel10k config
- `macOS`: Folder for macOS specific install scripts and icons

## Requirements
- `git`: To clone this repo
Link to oh-my-zsh
- `curl`: To install [`oh-my-zsh`](https://ohmyz.sh/)
- `sudo`: If you want to install sudo required packages (linux only)
- Package manager: Currently supports `apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `emerge`, and `brew` for macOS
    - Only required if you want to install packages

## What it does
- Installs [`oh-my-zsh`](https://ohmyz.sh/)
    - Installs the [`zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions) plugin
    - Installs the [`zsh-syntax-highlighting`](https://github.com/zsh-users/zsh-syntax-highlighting) plugin

- Installs [`powerlevel10k`](https://github.com/romkatv/powerlevel10k) theme for `oh-my-zsh`
    - Manually install the following Meslo Nerd Fonts for best results:
    - [MesloLGS NF Regular.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf)
   - [MesloLGS NF Bold.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf)
   - [MesloLGS NF Italic.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf)
   - [MesloLGS NF Bold Italic.ttf](
       https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf)

- Installs the [dracula](https://draculatheme.com/vim) theme for `vim`

- Installs packages (if run with `-s`)
    - Currently `vim`, `wget`, and `neofetch`
    - Installs [`SDKMAN!`](https://sdkman.io/) for managing Java versions

- Copies dotfiles to the home directory
    - Backs up existing dotfiles if they exist
    - Backups can be found in the home directory with the extension `.bak`

- Creates symlinks for the dotfiles in this repo (if run with `-l`)
    - Use this option if you want to keep your dotfiles in sync with this repo

## Installation
```bash
git clone https://github.com/ajholzbach/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

- If you want to install sudo required packages, run `./install.sh -s`
- If you want to create symlinks for the dotfiles in this repo, run `./install.sh -l`

## Removal
```bash
cd ~
rm -rf .dotfiles
```

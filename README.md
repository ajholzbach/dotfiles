# dotfiles
A repo to store my dotfiles + a comprehensive install script

## Contents
- `install.sh`: Installs dotfiles and other packages (if specified)
- `.zshrc`: Zsh config
- `.vimrc`: Vim config
- `.p10k.zsh`: Powerlevel10k config

## Requirements
- `git`: To clone this repo
Link to oh-my-zsh
- `curl`: To install [`oh-my-zsh`](https://ohmyz.sh/)
- `sudo`: If you want to install sudo required packages (linux only)
- Package manager: Currently supports `apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, `emerge`, and `brew` for macOS
    - Only required if you want to install packages

## What it does
- Installs `oh-my-zsh`
    - Installs the `zsh-autosuggestions` plugin
    - Installs the `zsh-syntax-highlighting` plugin

- Installs `powerlevel10k` theme for `oh-my-zsh`

- Installs the [dracula](https://draculatheme.com/vim) theme for `vim`

- Installs packages (if run with `-s`)
    - Currently `vim`, `wget`, and `neofetch`

- Copies dotfiles to the home directory
    - Backs up existing dotfiles if they exist
    - Backups can be found in the home directory with the extension `.bak`

- Creates symlinks for the dotfiles in this repo (if run with `-l`)
    - Use this option if you want to keep your dotfiles in sync with this repo

## Installation
```bash
git clone https://github.com/ajholzbach/dotfiles.git
cd ~/dotfiles
./install.sh
```

- If you want to install sudo required packages, run `./install.sh -s`
- If you want to create symlinks for the dotfiles in this repo, run `./install.sh -l`

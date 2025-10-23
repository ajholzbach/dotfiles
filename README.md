# dotfiles

Personal dotfiles managed with [Chezmoi](https://github.com/twpayne/chezmoi). The active, up-to-date configuration lives under `home/` and is applied to `$HOME` via Chezmoi.

![Sample Command Line](assets/sample_command_line_2.png)

## Status

This repository is fully managed by Chezmoi. All active dotfiles are in `home/` and automatically applied to `$HOME`.

## Layout

- `home/`: Source of truth for dotfiles used by Chezmoi (mirrors `$HOME` layout)
- `home/.chezmoiscripts/`: Automated installation scripts for fonts, Starship, Antidote, etc.
- `tests/`: Docker-based test suite for Ubuntu installation validation
- `macOS/`: macOS-specific utilities (icons, optional install scripts)
- `assets/`: Screenshots and images for documentation
- `archive/`: Historical reference - old dotfiles, installers, and scripts before Chezmoi migration

## What's Included

The `home/` directory contains the following dotfiles and configurations:

### Shell Configuration
- **zsh**: Custom `.zshrc` with optimizations for performance (lazy-loading for conda, nvm, pnpm), tool integrations, and Catppuccin theme support
- **bash**: Basic `.bashrc` configuration
- [**fish**](https://github.com/fish-shell/fish-shell): Full Fish shell configuration with Fisher plugin manager setup and optimal integrations

### Development Tools
- **git**: Global `.gitignore` with common ignore patterns
- **vim**: Custom configuration with Catppuccin Mocha colorscheme
- [**starship**](https://starship.rs/): Cross-shell prompt with custom symbols and OS detection
- [**bat**](https://github.com/sharkdp/bat): Syntax highlighting configuration with Catppuccin Mocha theme
- [**zoxide**](https://github.com/ajeetdsouza/zoxide): Smart directory jumping (aliased to `cd` in zsh)
- [**mise**](https://mise.jdx.dev/): Development environment manager integration
- [**conda**](https://github.com/conda-forge/miniforge): Lazy-load configuration for faster shell startup

### Applications
- [**Ghostty**](https://ghostty.org/): Terminal emulator configuration
- [**Zed**](https://zed.dev/): Text editor settings

All configurations use the [**Catppuccin Mocha**](https://catppuccin.com/palette/) theme for consistent visual experience across tools.

## Install (Linux or macOS)

- One-liner:

```bash
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply ajholzbach
```

- With Homebrew:

```bash
brew install chezmoi
chezmoi init --apply ajholzbach
```

This will clone the repo as a Chezmoi source and immediately apply the files from `home/` into your `$HOME`. Chezmoi scripts will automatically install Homebrew (macOS), fonts, Starship, and Antidote.

## Recommended Packages

To get the full experience from these dotfiles, consider installing these optional packages:

### Essential Tools

#### [Starship](https://starship.rs/) (Cross-shell prompt)
**Installed automatically by Chezmoi scripts.** Provides the customized prompt with OS detection, git status, and development environment info.

#### [Fish Shell](https://github.com/fish-shell/fish-shell)
**Why**: Modern shell with excellent autocompletion and scripting. Includes full configuration with Fisher plugin manager.
```bash
# macOS
brew install fish

# Linux
# Ubuntu/Debian: apt install fish
# Fedora: dnf install fish
# Or via mise: mise install fish
```

#### [Mise](https://mise.jdx.dev/) (Development Environment Manager)
**Why**: Manages development tool versions (Node.js, Python, Go, etc.) and installs.
```bash
# macOS
brew install mise

# Linux
curl https://mise.run | sh
```

### Quality of Life Improvements

#### [Bat](https://github.com/sharkdp/bat) (Enhanced cat)
**Why**: Syntax highlighting and Git integration for file viewing. Pre-configured with Catppuccin theme.
```bash
# macOS
brew install bat

# Linux (via mise - easier than most package managers)
mise install bat
```

#### [Zoxide](https://github.com/ajeetdsouza/zoxide) (Smart cd)
**Why**: Learns your directory usage patterns and provides fast navigation. Aliased to `cd` in zsh config.
```bash
# macOS
brew install zoxide

# Linux (via mise recommended)
mise install zoxide
```

### Post-Install Setup
After installing Fish, run once to set it as your default shell:
```bash
# Add fish to valid shells and set as default
echo $(which fish) | sudo tee -a /etc/shells
chsh -s $(which fish)
```

## Testing

Test the dotfiles installation on Ubuntu using Docker:

```bash
./tests/test.sh
```

See `tests/README.md` for details.

## Notes

- Legacy files from pre-Chezmoi setup are archived in `archive/` for reference only
- All active configuration is managed through `home/` and Chezmoi
- See `home/.chezmoiscripts/` for automated setup steps (fonts, tools, etc.)

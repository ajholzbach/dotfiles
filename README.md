# dotfiles

Personal dotfiles managed with [Chezmoi](https://github.com/twpayne/chezmoi). The active, up-to-date configuration lives under `home/` and is applied to `$HOME` via Chezmoi.

![Sample Command Line](assets/sample_command_line.png)

## Status

This repository is fully managed by Chezmoi. All active dotfiles are in `home/` and automatically applied to `$HOME`. Only the latest stable [Starship](https://starship.rs/) is installed automatically; Fish is recommended, and all other tools are optional.

## Layout

- `home/`: Source of truth for dotfiles used by Chezmoi (mirrors `$HOME` layout)
- `home/.chezmoiscripts/`: Restore-point creation, Starship installation, and Windows PowerShell profile setup
- `tests/`: Docker-based test suites for minimal Ubuntu, Ubuntu, Arch, and rendered Windows PowerShell scripts
- `assets/`: Screenshots and images for documentation
- `uninstall.sh` / `uninstall.ps1`: Restore the pre-install state or preview that restoration

## What's Included

The `home/` directory contains the following dotfiles and configurations:

### Shell Configuration
- **zsh**: Custom `.zshrc` with performance optimizations (lazy-loading for conda, nvm, pnpm), tool integrations, and Catppuccin theme support. Loads plugins via [Antidote](https://github.com/mattmc3/antidote) (`.zsh_plugins.txt`) when Antidote is installed.
- **bash**: `.bashrc` sources `~/.profile`, the per-machine env file, and initializes Starship.
- [**fish**](https://github.com/fish-shell/fish-shell): Full Fish configuration that works without plugins. The optional `fisher_setup` function installs [Fisher](https://github.com/jorgebucaran/fisher), syncs `dot_config/fish/fish_plugins`, and applies the Catppuccin Mocha theme when run explicitly.
- [**xonsh**](https://xon.sh/): Python-powered shell. `dot_config/xonsh/rc.xsh` mirrors the Fish setup, with a `tool-requirements.txt` for the uv-managed Python env and a `rc.d/` for drop-in scripts (`git-aliases.xsh`, lazy-loading `conda.xsh`). Xonsh itself is installed separately.
- **PowerShell**: Shared Starship and optional-tool initialization in `~/.config/powershell/profile.ps1`, loaded from the standard PowerShell profile locations on Windows.
- **shared `.profile`**: POSIX-clean env (XDG paths, PATH bootstrap, EDITOR, etc.) sourced by both Bash and zsh.

### Per-machine local env
Any machine-specific exports (work tokens, internal credentials, per-host overrides) live in `~/.config/local-env.sh` (POSIX), `~/.config/local-env.fish` (Fish), or `~/.config/local-env.ps1` (PowerShell), **outside this repository**, mode 600 where supported. Each shell sources its matching file if present, so the same dotfiles work across machines without leaking machine-local values into git.

### Development Tools
- **git**: Global ignore patterns at `~/.config/git/ignore`.
- **vim**: Custom `.vimrc` with Catppuccin Mocha colorscheme.
- [**starship**](https://starship.rs/): Cross-shell prompt with custom symbols, OS detection, and a shared `starship.toml` in `dot_config/`. The latest stable release is installed automatically when Starship is not already available.
- [**bat**](https://github.com/sharkdp/bat): Syntax highlighting configuration with Catppuccin Mocha theme.
- [**zoxide**](https://github.com/ajeetdsouza/zoxide): Smart directory jumping when installed.
- [**mise**](https://mise.jdx.dev/): Optional development environment manager integration in Bash, zsh, Fish, and Xonsh. No Chezmoi script requires mise. Shared settings live in `dot_config/mise/conf.d/00-baseline.toml`; per-machine `[tools]` belong in the intentionally unmanaged `~/.config/mise/config.toml`.
- [**conda**](https://github.com/conda-forge/miniforge): Lazy-load setup for fast shell startup; Xonsh wraps `conda shell.xonsh hook` so a fresh shell does not pay the initialization cost until the first `conda` invocation.
- [**fzf**](https://github.com/junegunn/fzf): Fuzzy finder integration when installed.

### Applications
- [**Ghostty**](https://ghostty.org/): Terminal emulator configuration (Catppuccin Mocha theme, MesloLGS Nerd Font, `display-p3` colorspace on macOS).
- [**Zed**](https://zed.dev/): Text editor settings.
- [**tmux**](https://github.com/tmux/tmux/wiki): Terminal multiplexer config in `dot_config/tmux/`.
- [**cmux**](https://github.com/manaflow-ai/cmux): macOS-native multiplexer config in `dot_config/cmux/`.
- [**btop**](https://github.com/aristocratos/btop): System monitor (themes only; per-machine `btop.conf` stays local).

All configurations use the [**Catppuccin Mocha**](https://catppuccin.com/palette/) theme for consistent visual experience across tools.

## Install (Linux or macOS)

- One-liner:

```bash
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply ajholzbach
```

- With Homebrew:

```bash
brew install chezmoi
chezmoi init --apply ajholzbach
```

This clones the repository as a Chezmoi source and immediately applies the files from `home/` into `$HOME`. The bootstrap scripts then:

1. Create or update a pre-install restore point before any managed file changes.
2. Install the latest stable Starship into a user-local directory when Starship is absent.
3. On Windows, add a marked loader to the standard PowerShell profile files while preserving existing content.

The scripts do not use `sudo`, install a shell, change the login shell, or call an operating-system package manager.

### Arch and CachyOS

Use the same one-liner above. The bootstrap has no dependency on pacman or Shelly because Chezmoi and Starship are installed in user-local directories. The Arch path is covered by the Docker suite; CachyOS itself is not emulated separately.

### Windows

Install Chezmoi for the current user, refresh the process PATH, and apply:

```powershell
winget install --id twpayne.chezmoi --exact --scope user --installer-type portable
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + [IO.Path]::PathSeparator + [Environment]::GetEnvironmentVariable('Path', 'User')
chezmoi init --apply ajholzbach
```

The Windows scripts install the latest available Starship through WinGet, with Scoop as a fallback, and load the shared `~/.config/powershell/profile.ps1` from PowerShell 7 and Windows PowerShell.

## Uninstall

Preview and then restore the state captured before the first apply:

```bash
sh "$(chezmoi source-path)/uninstall.sh" --dry-run
sh "$(chezmoi source-path)/uninstall.sh" --yes
```

PowerShell equivalents:

```powershell
$uninstall = Join-Path (chezmoi source-path) 'uninstall.ps1'
& $uninstall -DryRun
& $uninstall -Yes
```

The uninstall helpers restore previous files, remove newly managed targets, and remove Starship only when it was installed by these dotfiles and is still unchanged. Add `--keep-chezmoi` or `-KeepChezmoi` to preserve the local Chezmoi source and metadata.

## Recommended Packages

To get the full experience from these dotfiles, consider installing these optional packages:

### Essential Tools

#### [Starship](https://starship.rs/) (Cross-shell prompt)
**Installed automatically by Chezmoi scripts.** Provides the customized prompt with OS detection, git status, and development environment info.

### Recommended Tools

#### [Fish Shell](https://github.com/fish-shell/fish-shell)
**Why**: Modern shell with excellent autocompletion and scripting. The configuration also works without Fish, so using it is a preference rather than an installation requirement.
```bash
# macOS
brew install fish

# Linux
# Follow instructions at https://fishshell.com/
```

### Optional Tools

#### [Mise](https://mise.jdx.dev/) (Development Environment Manager)
**Why**: Manages development tool versions (Node.js, Go, Java, etc.). No Chezmoi script depends on it.
```bash
# macOS
brew install mise

# Linux
curl https://mise.run | sh
```

### Quality of Life Improvements

#### [Bat](https://github.com/sharkdp/bat) (Enhanced cat)
**Why**: Syntax highlighting and Git integration for file viewing. Pre-configured with Catppuccin theme and used by guarded aliases when available.
```bash
# macOS
brew install bat

# Cross-platform with mise
mise use -g bat
```

#### [Zoxide](https://github.com/ajeetdsouza/zoxide) (Smart cd)
**Why**: Learns your directory usage patterns and provides fast navigation when installed.
```bash
# macOS
brew install zoxide

# Cross-platform with mise
mise use -g zoxide
```

#### [Xonsh](https://xon.sh/) (Python-powered shell, optional)
**Why**: Hybrid Python/shell syntax for when you want real Python objects in your pipelines. Side-by-side with Fish; not a login shell.
```bash
# Recommended: uv tool install (cross-platform, isolated)
uv tool install --managed-python 'xonsh[full]' \
  --with-requirements ~/.config/xonsh/tool-requirements.txt
```

#### [gawk](https://www.gnu.org/software/gawk/) (faster zsh startup)
**Why**: Antidote probes for `gawk` at shell startup. Installing it avoids the fallback scan and is useful for GNU-awk scripts in general.
```bash
# macOS
brew install gawk

# Linux examples
sudo apt install gawk     # Debian/Ubuntu
sudo dnf install gawk     # Fedora
sudo pacman -S gawk       # Arch/CachyOS
```

### Post-Install Setup

The bootstrap does not change the account's default shell. If Fish should be the login shell, first verify that its path is listed in `/etc/shells`, then run:

```bash
chsh -s "$(command -v fish)"
```

For machine-local environment values, create the matching file without placing secret values in shell history:

```bash
umask 077
mkdir -p ~/.config
${EDITOR:-vi} ~/.config/local-env.sh
```

Use `~/.config/local-env.fish` for Fish syntax and `~/.config/local-env.ps1` for PowerShell syntax.

## Testing

Run the complete local Docker gate before pushing:

```bash
./tests/test.sh all
```

The selectors are `minimal`, `ubuntu`, `arch`, and `powershell`. The PowerShell suite runs rendered Windows scripts under `pwsh` with mocked package managers; it is not a native-Windows test. See `tests/README.md` for details.

## Notes

- All active configuration is managed through `home/` and Chezmoi.
- Machine-local env (secrets, work credentials, per-host overrides) lives in `~/.config/local-env.{sh,fish,ps1}` outside this repository.
- Xonsh-specific package management uses `~/.config/xonsh/tool-requirements.txt` as the source of truth for what is installed alongside Xonsh in its uv tool environment. Rebuild after editing with:
  ```bash
  uv tool install --reinstall --managed-python 'xonsh[full]' \
    --with-requirements ~/.config/xonsh/tool-requirements.txt
  ```

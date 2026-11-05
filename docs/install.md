# Install

## Linux and macOS

The one-line install requires [curl](https://curl.se/download.html). [Git](https://git-scm.com/downloads) is also required when zsh is present and Antidote needs to be installed. The tools install adds Git on Linux.

The one-line install downloads chezmoi, initializes this repository, and applies it. Choose one:

```sh
# Dotfiles only
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply --promptDefaults ajholzbach

# Dotfiles and recommended tools
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply --promptBool tools=true ajholzbach
```

Without either flag, chezmoi asks once and saves the answer in `~/.config/chezmoi/chezmoi.toml`.

On macOS, both installs add MesloLGS Nerd Font with the Homebrew cask `font-meslo-lg-nerd-font`. Without Homebrew, the dotfiles install skips the font and tells you to install Homebrew. The tools install adds Homebrew first.

To review the changes before applying them:

```sh
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init ajholzbach
~/.local/bin/chezmoi diff
~/.local/bin/chezmoi apply
```

If installing with Homebrew is preferred:

```sh
brew install chezmoi
chezmoi init --apply ajholzbach
```

## Change the install type

```sh
chezmoi init --apply --prompt --promptBool tools=true
```

Use `=false` to go back to dotfiles only. Installed tools stay installed.

`chezmoi init` rewrites `~/.config/chezmoi/chezmoi.toml`. Only the `tools` answer and the `kube` data carry over.

## Windows

Install chezmoi for the current user, refresh the process path, and apply:

```powershell
winget install --id twpayne.chezmoi --exact --scope user --installer-type portable
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + [IO.Path]::PathSeparator + [Environment]::GetEnvironmentVariable('Path', 'User')
chezmoi init --apply ajholzbach
```

Windows gets the dotfiles only. The setup installs Starship through WinGet with Scoop as a fallback. It loads the shared PowerShell profile from PowerShell 7 and Windows PowerShell. Install [MesloLGS Nerd Font](https://www.nerdfonts.com/font-downloads) manually.

# dotfiles

These are my shell and tool configurations. [chezmoi](https://www.chezmoi.io/) maps the files under `home/` into `$HOME` and keeps the source state in one repository.

![Sample command line](assets/sample_command_line.png)

## What this repository does

- Applies configuration for Bash, zsh, Fish, Xonsh, and PowerShell
- Installs the latest stable [Starship](https://starship.rs/) when it is missing
- Installs [Antidote](https://github.com/mattmc3/antidote) on Linux and macOS when zsh is present
- Applies the included Catppuccin Mocha theme on Linux and macOS when Fish is present
- Gives Claude Code and Codex the same agent instructions and installs RTK hooks when RTK is present
- Creates a restore point before changing managed files
- Provides tested uninstall scripts for restoring the previous state

Starship is the only program installed on every supported platform. On Linux and macOS it is installed in `~/.local/bin` without `sudo` or a package manager. On Windows its installer uses WinGet with Scoop as a fallback. The bootstrap does not install a shell, Fisher, or optional tools. It does not change the login shell.

## Repository layout

- `home/` contains the files applied to `$HOME`
- `home/.chezmoiscripts/` contains setup and restore-point scripts
- `tests/` contains the Docker test suites
- `assets/` contains README images
- `uninstall.sh` and `uninstall.ps1` restore the pre-install state

Generated plugin files, shell history, installed programs, and machine-specific environment files are not tracked.

## Managed configuration

### Shells

- **Bash** sources the shared `.profile`, local environment values, and guarded tool integrations.
- **zsh** includes completion, history settings, lazy Conda and NVM loading, Antidote plugins, and guarded tool integrations.
- **Fish** works without Fisher. Its optional aliases come from autoloaded plugin functions so they add no work to shell startup.
- **Xonsh** includes guarded integrations, lazy Conda loading, and Git aliases.
- **PowerShell** uses a shared profile loaded from the standard PowerShell profile locations on Windows.

### Installation behavior

- [Starship](https://starship.rs/) is installed automatically when missing because it provides the shared prompt.
- [Antidote](https://github.com/mattmc3/antidote) is installed when zsh is already present on Linux or macOS.
- The Fish theme is applied when Fish is already present on Linux or macOS.
- All other tools are installed manually. Their configuration activates only when the corresponding program is available.

### Optional integrations

- [eza](https://eza.rocks/) backs the guarded `ls`, `ll`, `la`, and `lt` aliases in zsh and the Fish plugin.
- [bat](https://github.com/sharkdp/bat) provides the configured `cat` alias and Catppuccin theme.
- [zoxide](https://github.com/ajeetdsouza/zoxide) provides history-based directory navigation.
- [fzf](https://github.com/junegunn/fzf) provides fuzzy completion and key bindings.
- [mise](https://mise.jdx.dev/) activates development tools using the shared baseline configuration.
- Conda loads only when first used to keep shell startup fast.
- Vim, tmux, and btop have managed configuration but are not installed.
- zsh provides a resumable `wget` alias, extension-aware `tarnow` and `untar` helpers, and portable `psmem` and `psmem10` memory views. The matching Fish functions come from [ajholzbach/fish](https://github.com/ajholzbach/fish).

### Fish plugins

Fish works without [Fisher](https://github.com/jorgebucaran/fisher). Neither Fisher nor its plugins are installed by the bootstrap. After Fisher is installed, `fisher_setup` syncs the tracked [`fish_plugins`](home/dot_config/fish/fish_plugins) list.

I maintain all three tracked plugins:

- [ajholzbach/fish](https://github.com/ajholzbach/fish) provides shared Fish functions and completions, including the eza, wget, tar, and memory helpers.
- [ajholzbach/fish-git](https://github.com/ajholzbach/fish-git) provides lazy-loaded Git aliases.
- [ajholzbach/fish-kubectl](https://github.com/ajholzbach/fish-kubectl) provides lazy-loaded kubectl aliases and completions.

### Applications

- [Ghostty](https://ghostty.org/) has a Catppuccin Mocha terminal configuration.
- [Zed](https://zed.dev/) has editor settings.

## Install on Linux or macOS

The one-line path requires [curl](https://curl.se/download.html). [Git](https://git-scm.com/downloads) is also required when zsh is present and Antidote needs to be installed. Neither tool is installed by these dotfiles.

The one-line install downloads chezmoi, initializes this repository, and applies it:

```sh
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply ajholzbach
```

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

## Install on Windows

Install chezmoi for the current user, refresh the process path, and apply:

```powershell
winget install --id twpayne.chezmoi --exact --scope user --installer-type portable
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + [IO.Path]::PathSeparator + [Environment]::GetEnvironmentVariable('Path', 'User')
chezmoi init --apply ajholzbach
```

The Windows setup installs Starship through WinGet with Scoop as a fallback. It loads the shared PowerShell profile from PowerShell 7 and Windows PowerShell.

## Recommended tools

The tools below are recommended and installed separately. Their configuration is guarded, so none are required for `chezmoi apply`.

| Tool | What it enables | Installation |
| --- | --- | --- |
| MesloLG Nerd Font | Prompt and eza icons plus the configured font in Ghostty and Zed | [Official download](https://www.nerdfonts.com/font-downloads) |
| Fish | The primary interactive shell setup with autoloaded functions | [Official packages](https://fishshell.com/) |
| eza | `ls`, `ll`, `la`, and `lt` aliases with icons and directory grouping | [Official instructions](https://eza.rocks/) |
| bat | The configured `cat` alias and Catppuccin theme | [Official instructions](https://github.com/sharkdp/bat#installation) |
| zoxide | Directory navigation based on command history | [Official instructions](https://github.com/ajeetdsouza/zoxide#installation) |
| Fisher | The three tracked Fish plugins | [Official instructions](https://github.com/jorgebucaran/fisher#installation) |
| fzf | Fuzzy completion and shell key bindings | [Official instructions](https://github.com/junegunn/fzf#installation) |
| mise | Development tool versions and shell activation | [Official instructions](https://mise.jdx.dev/installing-mise.html) |

## After installation

Nothing changes the account's default shell. To use Fish as the login shell, first confirm that its path is listed in `/etc/shells`, then run:

```sh
chsh -s "$(command -v fish)"
```

After following Fisher's [installation instructions](https://github.com/jorgebucaran/fisher#installation), sync the tracked plugin list with:

```fish
fisher_setup
```

Xonsh is also optional. Install its managed Python environment with:

```sh
uv tool install --managed-python 'xonsh[full]' \
  --with-requirements ~/.config/xonsh/tool-requirements.txt
```

Keep machine-specific values outside the repository:

- `~/.config/local-env.sh` for Bash and zsh
- `~/.config/local-env.fish` for Fish
- `~/.config/local-env.ps1` for PowerShell

For example:

```sh
umask 077
mkdir -p ~/.config
${EDITOR:-vi} ~/.config/local-env.sh
```

## Uninstall

Preview the restore:

```sh
sh "$(chezmoi source-path)/uninstall.sh" --dry-run
```

Restore the pre-install state:

```sh
sh "$(chezmoi source-path)/uninstall.sh" --yes
```

Use `--keep-chezmoi` to preserve the local chezmoi source and metadata.

On Windows:

```powershell
$uninstall = Join-Path (chezmoi source-path) 'uninstall.ps1'
& $uninstall -DryRun
& $uninstall -Yes
```

## Testing

Run the complete Docker gate before pushing:

```sh
./tests/test.sh all
```

The selectors are `minimal`, `ubuntu`, `arch`, and `powershell`. The PowerShell suite renders and tests the Windows scripts under `pwsh`. It is not a native Windows test.

See [tests/README.md](tests/README.md) for the full test matrix and troubleshooting notes.

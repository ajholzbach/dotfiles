# dotfiles

![Test](https://github.com/ajholzbach/dotfiles/actions/workflows/test.yml/badge.svg)

Shell and tool configurations managed with [chezmoi](https://www.chezmoi.io/).

![Sample command line](assets/sample_command_line.png)

## Install

Dotfiles and the [recommended tools](docs/tools.md), on Linux or macOS:

```sh
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply --promptBool tools=true ajholzbach
```

See [docs/install.md](docs/install.md) for the dotfiles-only install, Windows, and other install options.

## What this repository does

- Applies configuration for Bash, zsh, Fish, Xonsh, and PowerShell
- Installs the latest stable [Starship](https://starship.rs/) when it is missing
- Installs MesloLGS Nerd Font on Linux and macOS
- Installs [Antidote](https://github.com/mattmc3/antidote) on Linux and macOS when zsh is present
- On macOS, the tools install gets chezmoi, Starship, Antidote, and the font from Homebrew
- Uses the [Catppuccin Mocha](https://catppuccin.com/palette/) theme wherever possible
- Gives Claude Code and Codex the same agent instructions and installs RTK hooks when RTK is present
- Creates a restore point before changing managed files

## Managed configuration

This section lists the main changes. The files in [`home/`](home/) have the full configuration.

- [Starship](https://starship.rs/) gives Bash, zsh, Fish, Xonsh, and PowerShell the same prompt.
- zsh gets autosuggestions and syntax highlighting from [Antidote](https://github.com/mattmc3/antidote) plugins, plus cached completion and shared history.
- Fish gets the Catppuccin Mocha theme, extra completions, and the [Fish plugins](#fish-plugins).
- Shell startup is tuned for speed. Conda and NVM load on first use, zsh and Fish cache the Starship, zoxide, and fzf init scripts, and zsh caches its plugin bundle and completion dump.
- [mise](https://mise.jdx.dev/) activates in every shell.

These tools integrate with Bash, zsh, Fish, and Xonsh, unless the table says otherwise:

| Tool | Integration |
| --- | --- |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` jumps to frequent directories. In Bash and zsh, `cdo` runs the built-in `cd`. |
| [bat](https://github.com/sharkdp/bat) | `cat` shows syntax highlighting. |
| [eza](https://eza.rocks/) | `ls`, `ll`, `la`, and `lt` show icons and list directories first. zsh and Fish only. |
| [fzf](https://github.com/junegunn/fzf) | Ctrl+R, Ctrl+T, and Alt+C search history, files, and directories. zsh and Fish only. |

Other programs, such as [Ghostty](https://ghostty.org/), [Zed](https://zed.dev/), tmux, Vim, zellij, btop, and Git, get small configuration changes, mostly the Catppuccin Mocha theme and MesloLGS Nerd Font.

Each integration activates only when its program is installed.

## Fish plugins

[Fisher](https://github.com/jorgebucaran/fisher) installs these plugins from [`fish_plugins`](home/dot_config/fish/fish_plugins):

- [ajholzbach/fish-git](https://github.com/ajholzbach/fish-git) provides lazy-loaded Git aliases.
- [ajholzbach/fish-kubectl](https://github.com/ajholzbach/fish-kubectl) provides lazy-loaded kubectl aliases and completions.

## Local overrides

Keep machine-specific values in these untracked files:

- `~/.config/local-env.sh` for Bash and zsh
- `~/.config/local-env.fish` for Fish
- `~/.config/local-env.ps1` for PowerShell

Apply keeps the blocks that other tools add to `~/.bash_profile` between `# >>> name >>>` and `# <<< name <<<` lines.

## Repository layout

- `home/` contains the files applied to `$HOME`
- `home/.chezmoiscripts/` contains setup and restore-point scripts
- `home/dot_config/mise/conf.d/10-dotfiles-tools.toml` lists the recommended tools
- `docs/` contains the install, tools, and uninstall guides
- `tests/` contains the Docker test suites, which GitHub Actions runs on each push
- `uninstall.sh` and `uninstall.ps1` restore the pre-install state

## Docs

- [Install](docs/install.md)
- [Recommended tools](docs/tools.md)
- [Uninstall](docs/uninstall.md)
- [Testing](tests/README.md)

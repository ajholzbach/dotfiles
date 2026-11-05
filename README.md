# dotfiles

Shell and tool configurations managed with [chezmoi](https://www.chezmoi.io/).

![Sample command line](assets/sample_command_line.png)

## Install

Dotfiles only, on Linux or macOS:

```sh
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply --promptDefaults ajholzbach
```

Dotfiles and the [recommended tools](docs/tools.md):

```sh
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply --promptBool tools=true ajholzbach
```

See [docs/install.md](docs/install.md) for Windows and other install options.

## What this repository does

- Applies configuration for Bash, zsh, Fish, Xonsh, and PowerShell
- Installs the latest stable [Starship](https://starship.rs/) when it is missing
- Installs MesloLGS Nerd Font on Linux, and with Homebrew on macOS
- Installs [Antidote](https://github.com/mattmc3/antidote) on Linux and macOS when zsh is present
- Applies the included Catppuccin Mocha theme on Linux and macOS when Fish is present
- Gives Claude Code and Codex the same agent instructions and installs RTK hooks when RTK is present
- Creates a restore point before changing managed files

## Managed configuration

| Program | Configuration |
| --- | --- |
| Bash | Shared `.profile`, local environment, and guarded tool integrations |
| zsh | Completion, history, lazy Conda and NVM, Antidote plugins, and `wget`, `tarnow`, `untar`, and `psmem` helpers |
| Fish | Autoloaded functions, the Catppuccin Mocha theme, and the Fisher plugin list |
| Xonsh | Guarded integrations, lazy Conda, and Git aliases |
| PowerShell | One shared profile for PowerShell 7 and Windows PowerShell |
| [eza](https://eza.rocks/) | `ls`, `ll`, `la`, and `lt` aliases with icons and directory grouping |
| [bat](https://github.com/sharkdp/bat) | `cat` alias and Catppuccin theme |
| [zoxide](https://github.com/ajeetdsouza/zoxide), [fzf](https://github.com/junegunn/fzf), [mise](https://mise.jdx.dev/) | Shell integration |
| [Ghostty](https://ghostty.org/), [Zed](https://zed.dev/) | Catppuccin Mocha and MesloLGS Nerd Font |
| Vim, tmux, btop | Configuration and themes |

Each integration activates only when its program is installed.

## Fish plugins

[Fisher](https://github.com/jorgebucaran/fisher) installs these plugins from [`fish_plugins`](home/dot_config/fish/fish_plugins):

- [ajholzbach/fish](https://github.com/ajholzbach/fish) provides shared Fish functions and completions, including the eza, wget, tar, and memory helpers.
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
- `tests/` contains the Docker test suites
- `uninstall.sh` and `uninstall.ps1` restore the pre-install state

## Docs

- [Install](docs/install.md)
- [Recommended tools](docs/tools.md)
- [Uninstall](docs/uninstall.md)
- [Testing](tests/README.md)

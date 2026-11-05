# Recommended tools

The tools install adds the programs below. It installs [mise](https://mise.jdx.dev/) when it is missing, then runs [`mise bootstrap`](https://mise.jdx.dev/bootstrap.html) for the packages and tools in [`10-dotfiles-tools.toml`](../home/dot_config/mise/conf.d/10-dotfiles-tools.toml).

| System | Installer |
| --- | --- |
| macOS | Homebrew, installed first when it is missing. mise installs bat, eza, Fish, fzf, and zoxide as Homebrew formulae |
| Debian and Ubuntu | apt for Fish, Git, and zsh. mise for bat, eza, fzf, and zoxide |
| Arch, CachyOS, and other Arch-based systems | pacman for Fish, Git, and zsh. mise for bat, eza, fzf, and zoxide |

mise skips the entries for package managers that the system does not have, and counts formulae that Homebrew already installed. On other Linux systems, only the mise tools install. On Intel Macs, mise skips the Homebrew formulae.

After the packages, it installs Fisher and the plugins in [`fish_plugins`](../home/dot_config/fish/fish_plugins). Fisher keeps exactly the plugins in that file. To add a plugin, add it to the file in the chezmoi source and apply.

On Linux, mise uses `sudo` only to install missing packages. The setup runs again when the mise config changes. Run `mise upgrade` on Linux or `brew upgrade` on macOS to update the CLI tools.

## Tools

| Tool | What it enables | Installation |
| --- | --- | --- |
| Fish | The primary interactive shell setup with autoloaded functions | [Official packages](https://fishshell.com/) |
| zsh | The zsh setup with Antidote plugins | Your system package manager |
| eza | `ls`, `ll`, `la`, and `lt` aliases with icons and directory grouping | [Official instructions](https://eza.rocks/) |
| bat | The configured `cat` alias and Catppuccin theme | [Official instructions](https://github.com/sharkdp/bat#installation) |
| zoxide | Directory navigation based on command history | [Official instructions](https://github.com/ajeetdsouza/zoxide#installation) |
| Fisher | The three tracked Fish plugins | [Official instructions](https://github.com/jorgebucaran/fisher#installation) |
| fzf | Fuzzy completion and shell key bindings | [Official instructions](https://github.com/junegunn/fzf#installation) |
| mise | Development tool versions and shell activation | [Official instructions](https://mise.jdx.dev/installing-mise.html) |

On other systems, install the tools manually. After installing Fisher, sync the tracked plugin list with:

```fish
fisher_setup
```

## After installation

To use Fish as the login shell, first confirm that its path is listed in `/etc/shells`, then run:

```sh
chsh -s "$(command -v fish)"
```

Xonsh is optional. Install its managed Python environment with:

```sh
uv tool install --managed-python 'xonsh[full]' \
  --with-requirements ~/.config/xonsh/tool-requirements.txt
```

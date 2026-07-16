# dotfiles

Portable dotfiles managed with [chezmoi](https://www.chezmoi.io/). The baseline is intentionally small: it installs Starship and applies configuration files, but it does not install a shell, package manager, language runtime, plugin manager, or font.

![Sample command line](assets/sample_command_line.png)

## Design goals

- One-command installation on macOS and common Linux distributions, including Ubuntu, Arch, and CachyOS
- Useful Bash defaults without requiring Fish, zsh, mise, or any other optional tool
- Shared Starship configuration for Bash, zsh, Fish, Xonsh, and PowerShell
- No `sudo` and no operating-system package-manager changes during `chezmoi apply`
- A pre-install restore point and a tested uninstall path
- Machine-local secrets and overrides kept outside the repository

Only Starship is treated as essential. If Starship is already installed, it is left untouched. The bootstrap otherwise installs the latest stable release into a user-local location. All other integrations are guarded by command-existence checks and remain dormant until the corresponding tool is installed.

## What is managed

- Shells: Bash, zsh, Fish, Xonsh, and PowerShell profiles
- Prompt: a shared Starship configuration
- Developer tools: optional configs for Git, Vim, bat, mise, tmux, and related shell integrations
- Applications: Ghostty, Zed, cmux, and btop configuration or themes
- Safety: first-apply restore points and POSIX/PowerShell uninstall helpers

The source state is under `home/`, as selected by `.chezmoiroot`. `tests/` contains the complete local Docker gate. `uninstall.sh` and `uninstall.ps1` restore the state captured before the first apply.

Generated plugin files, shell history, machine-local environment files, installed programs, and application data are deliberately not managed.

## Install

### Linux and macOS

The one-line path installs the latest available chezmoi into `~/.local/bin`, clones this repository, creates a restore point, and applies it:

```sh
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init --apply ajholzbach
```

The command follows chezmoi's documented [one-line installation flow](https://www.chezmoi.io/install/). It needs a POSIX shell, HTTPS-capable `curl`, trusted CA certificates, and the standard archive/checksum utilities normally present on macOS and general-purpose Linux distributions.

For a review-first installation, initialize without applying, inspect the diff, and then apply:

```sh
sh -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://get.chezmoi.io/lb)" -- init ajholzbach
~/.local/bin/chezmoi diff
~/.local/bin/chezmoi apply
```

The first apply prints the restore-point directory. It is normally:

```text
~/.local/state/dotfiles/backups/<timestamp>/
```

If `XDG_STATE_HOME` is set, that directory is used instead of `~/.local/state`.

Existing startup files are backed up, but their contents are never copied into another shell's startup path or executed as a different shell language. After installation, review the restore point and move any still-needed portable exports into the machine-local environment file described below.

The automatic scripts do only three things:

1. Capture all pre-existing managed files and symlinks before they are changed.
2. Install the latest stable Starship into `~/.local/bin` when no Starship command already exists.
3. On Windows, add a marker-delimited loader to the user's PowerShell profile files while preserving surrounding content.

### Arch and CachyOS

There is no Arch-specific installation branch and no dependency on Shelly or pacman. The bootstrap is entirely user-local, so the same one-line command applies.

CachyOS currently recommends `pacman` for command-line system package management and presents Shelly as a graphical pacman front end in its [package-manager guidance](https://wiki.cachyos.org/cachyos_basic/faq/#choosing-a-gui-package-manager). Either can be used to install optional tools, but neither is called by these dotfiles.

### Windows

Install chezmoi for the current user, refresh the process PATH, and apply:

```powershell
winget install --id twpayne.chezmoi --exact --scope user --installer-type portable
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + [IO.Path]::PathSeparator + [Environment]::GetEnvironmentVariable('Path', 'User')
chezmoi init --apply ajholzbach
```

The Windows bootstrap installs the latest available Starship through WinGet, with Scoop as a fallback, and validates the resulting command. Starship's official Windows options include both managers in its [installation guide](https://starship.rs/guide/#step-1-install-starship).

The managed PowerShell profile is shared at `~/.config/powershell/profile.ps1`. A small marked loader is inserted into both the PowerShell 7 and Windows PowerShell profile locations. Existing content and text encoding are preserved. Open a new PowerShell session after installation.

If machine policy blocks local profile scripts, follow the policy set by the machine administrator. Do not weaken an organization-managed execution policy merely for these dotfiles.

## Revert or stop managing

Preview a complete POSIX restore:

```sh
sh "$(chezmoi source-path)/uninstall.sh" --dry-run
```

Restore the pre-install files, remove targets that did not exist before installation, remove only the Starship binary installed by this repository, and purge chezmoi's local source/configuration:

```sh
sh "$(chezmoi source-path)/uninstall.sh" --yes
```

Keep the chezmoi source and metadata by adding `--keep-chezmoi`.

PowerShell equivalents are:

```powershell
$uninstall = Join-Path (chezmoi source-path) 'uninstall.ps1'
& $uninstall -DryRun
& $uninstall -Yes
```

Before restoring, the uninstall helper saves the current managed files in `~/.local/state/dotfiles/uninstall-snapshots/`. This keeps edits made after installation recoverable. The helper validates its manifest and refuses to remove files when the restore point is missing or incomplete.

If the goal is only to stop managing the files while leaving their current contents in place, use:

```sh
chezmoi purge --force
```

`chezmoi purge` removes chezmoi's local source/configuration; it is not a restore operation.
If the source was purged before running the restore helper, `chezmoi init ajholzbach` can fetch it again without applying it; then run the uninstall command above.

## Optional and recommended tools

### Fish

Fish is recommended, not required. Its managed config starts cleanly without Fisher. After installing Fish and [Fisher](https://github.com/jorgebucaran/fisher) deliberately, synchronize the managed plugin list and theme with:

```fish
fisher_setup
```

Nothing changes the account's login shell automatically. If Fish should become the login shell, review its path in `/etc/shells` and run `chsh` yourself.

### mise

mise is optional; no chezmoi script depends on it. When present, the configured shells activate it and `~/.config/mise/conf.d/00-baseline.toml` supplies shared settings. Per-machine tool selections belong in the intentionally unmanaged `~/.config/mise/config.toml`.

### Nerd Font

The prompt uses Nerd Font symbols. Install a Nerd Font using the mechanism appropriate for the machine, then select it in the terminal. MesloLGS Nerd Font matches the included Ghostty configuration. Fonts are not downloaded automatically.

### zsh plugins

The zsh configuration works without plugins. If [Antidote](https://github.com/mattmc3/antidote) is installed at `~/.antidote`, `.zsh_plugins.txt` is bundled and loaded. Antidote and the listed plugins are not cloned automatically.

### Other integrations

- bat: Catppuccin theme and guarded `cat` aliases in configured interactive shells
- zoxide: guarded smart-directory integration in Bash, zsh, Xonsh, and PowerShell
- fzf: guarded zsh integration; Fish behavior may also come from optional plugins
- Xonsh: install separately with `uv tool install --managed-python 'xonsh[full]' --with-requirements ~/.config/xonsh/tool-requirements.txt`
- Conda and NVM: lazy zsh integrations that discover common Linux and macOS installation paths

Starship supports additional shells beyond those configured here. Adding one only requires its normal Starship initialization line pointing at the managed `~/.config/starship.toml`.

## Machine-local environment

Keep credentials and host-specific settings outside chezmoi in one or more of:

- `~/.config/local-env.sh`
- `~/.config/local-env.fish`
- `~/.config/local-env.ps1`

For POSIX shells, create the file with a restrictive mode and edit it without placing the secret value in shell history:

```sh
umask 077
mkdir -p ~/.config
${EDITOR:-vi} ~/.config/local-env.sh
```

Use POSIX-compatible `export NAME=value` statements because Bash and zsh share the file. Fish and PowerShell source their corresponding native files.

## Routine use

```sh
chezmoi diff                 # preview source-to-home changes
chezmoi apply                # apply and run the idempotent bootstrap scripts
chezmoi update               # pull, preview/apply according to chezmoi settings
chezmoi cd                   # enter the source repository
```

## Testing

Every active script under `home/.chezmoiscripts/` must be present in the test coverage manifest. The complete pre-push gate is:

```sh
./tests/test.sh all
```

It builds fresh Docker images and covers:

- a minimal Ubuntu environment with no optional shell or tool
- Ubuntu optional-tool compatibility
- Arch optional-tool compatibility
- rendered Windows scripts executed under PowerShell with mocked package managers
- the documented `chezmoi init --apply` path
- a full second apply with scripts enabled
- byte/mode/symlink restoration and installer-owned Starship removal
- a sanitized repository mount with no host Git metadata or forwarded credentials

Selectors are available for `minimal`, `ubuntu`, `arch`, and `powershell`. The PowerShell suite is Windows-script compatibility testing under `pwsh`; it does not replace a native-Windows smoke test. See [tests/README.md](tests/README.md).

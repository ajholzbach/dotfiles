# Uninstall

Uninstall restores the files from the restore point and removes the font, Starship, and Antidote that the dotfiles installed. Packages, Fisher, and Fish plugins from the tools install stay installed. Uninstall removes `10-dotfiles-tools.toml`, so on Linux mise stops activating bat, eza, fzf, and zoxide.

Preview the restore:

```sh
sh "$(chezmoi source-path)/../uninstall.sh" --dry-run
```

Restore the pre-install state:

```sh
sh "$(chezmoi source-path)/../uninstall.sh" --yes
```

Use `--keep-chezmoi` to preserve the local chezmoi source and metadata.

On Windows:

```powershell
$uninstall = Join-Path (chezmoi source-path) '..\uninstall.ps1'
& $uninstall -DryRun
& $uninstall -Yes
```

# dotfiles

Personal dotfiles managed with [Chezmoi](https://github.com/twpayne/chezmoi). The active, up-to-date configuration lives under `home/` and is applied to `$HOME` via Chezmoi.

![Sample Command Line](assets/sample_command_line_2.png)

## Status

> Deprecated: `install.sh` and the legacy `dotfiles` listing are no longer used. They are kept for historical reference only. All current dotfiles are defined in `home/` and managed by Chezmoi.

## Layout

- `home/`: Source of truth for dotfiles used by Chezmoi (mirrors `$HOME` layout)
- `macOS/`: macOS-specific helpers and icons
- `scripts/`: Miscellaneous helpful scripts (not part of Chezmoi state)
- `catppuccin/`: Theme assets (e.g., Vim colorscheme, iTerm profile)
- `assets/`: Screenshots and images
- `backup/`: Legacy scripts and archived content
- Legacy root files like `.vimrc`, `.zshrc`, `.p10k.zsh`, etc. remain for reference; Chezmoi-managed versions live in `home/` (e.g., `home/dot_zshrc`).

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

This will clone the repo as a Chezmoi source and immediately apply the files from `home/` into your `$HOME`.

## Notes

- If you previously used `install.sh`, prefer a fresh setup with Chezmoi as above. The script is unmaintained.
- Explore `home/.chezmoiscripts/` for any on-apply hooks and bootstrap steps handled by Chezmoi.

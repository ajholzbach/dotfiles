# Dotfiles Testing

Lightweight Docker-based tests for the chezmoi source. The harness builds a minimal Ubuntu image, applies the dotfiles, re-applies managed files to ensure idempotency, and asserts a few key installs.

## Prerequisites

- Docker installed and running

## Run the Test

From the repository root:

```bash
./tests/test.sh
```

## What It Does

1) Builds an Ubuntu 22.04 image with curl, git, sudo, fish, zsh, mise, bat, ripgrep, fd, and chezmoi preinstalled under a non-root user (`testuser`).
2) Runs `tests/container-test.sh` inside the container, which:
   - Copies the repo to `~/.local/share/chezmoi`
   - Runs `chezmoi apply`, then re-runs `chezmoi apply --exclude=scripts` to check file idempotency and a clean `chezmoi diff --exclude=scripts`
   - Asserts key artifacts and shell startup:
     - Starship installed
     - mise installed
     - `usage` installed via mise
     - Antidote installed
     - `.zshrc` present
     - `~/.config/starship.toml` present
     - `~/.config/fish/completions/mise.fish` present
     - `~/.config/fish/completions/chezmoi.fish`, `bat.fish`, `rg.fish`, and `fd.fish` present
     - MesloLGS Nerd Font (>=4 variants) in Linux/macOS font paths
     - Git global `core.excludesfile` points to `~/.gitignore_global`
     - `bat --list-themes` includes `Catppuccin Mocha`
     - `zsh -ic 'exit'` succeeds
     - `fish -ic 'exit'` succeeds
     - Fisher is available inside fish
3) Summarizes pass/fail counts and exits non-zero on any failure.

## Expected Output

```
Building Docker image...
Running chezmoi installation test...

==> Setting up chezmoi source directory...
==> Running chezmoi apply...
Installing MesloLGS Nerd Font...
Installing starship with official installer...
Installing antidote zsh plugin manager...
==> Re-running chezmoi apply for idempotency...
  ✓ Second chezmoi apply succeeded with scripts excluded
  ✓ chezmoi diff clean after re-apply with scripts excluded

==> Verification Results:
  ✓ mise installed (mise 20XX.X.X)
  ✓ usage installed via mise
  ✓ Starship installed (starship X.Y.Z)
  ✓ Antidote installed
  ✓ .zshrc installed
  ✓ Starship config installed
  ✓ mise fish completions installed
  ✓ chezmoi fish completions installed
  ✓ bat fish completions installed
  ✓ rg fish completions installed
  ✓ fd fish completions installed
  ✓ MesloLGS Nerd Font installed (4 variants)
  ✓ git global excludesfile configured
  ✓ bat cache built with Catppuccin theme
  ✓ zsh startup succeeded
  ✓ fish startup succeeded
  ✓ Fisher available in fish

==> Summary: 20 passed, 0 failed
==> All tests passed!
```

## Manual Testing

To explore the container interactively:

```bash
docker build -t dotfiles-test tests/
docker run --rm -it -v "$(pwd):/dotfiles:ro" dotfiles-test bash
```

Inside the container, run the same steps as the automated test:

```bash
mkdir -p ~/.local/share
cp -r /dotfiles ~/.local/share/chezmoi
chezmoi apply -v
chezmoi apply -v --exclude=scripts  # idempotency check for managed files
chezmoi diff --exclude=scripts      # should be empty
```

Verify installations:

```bash
starship --version
mise --version
mise ls --installed usage
ls ~/.antidote/
ls ~/.local/share/fonts/
ls ~/.config/starship.toml
ls ~/.config/fish/completions/mise.fish
ls ~/.config/fish/completions/chezmoi.fish
ls ~/.config/fish/completions/bat.fish
ls ~/.config/fish/completions/rg.fish
ls ~/.config/fish/completions/fd.fish
git config --global --get core.excludesfile
bat --list-themes | grep 'Catppuccin Mocha'
zsh -ic 'exit'
fish -ic 'exit'
fish -ic 'functions -q fisher'
```

## Clean Up

The test container is automatically removed after it exits (`--rm` flag).

To remove the Docker image:

```bash
docker rmi dotfiles-test
```

## Troubleshooting

**Test fails with "Docker daemon not running"**
- Start Docker or OrbStack before running the test

**Test fails during chezmoi apply**
- Check the error messages in the output
- Try manual testing (see above) to explore the issue interactively

**Font count shows 0 or wrong number**
- The font installation may have partially failed
- Check font script logs in the "Running chezmoi apply" section

## CI Integration

The test exits with code 0 on success and code 1 on failure, making it suitable for CI pipelines:

```bash
./tests/test.sh && echo "Dotfiles valid" || echo "Dotfiles broken"
```

## Notes

- The `/dotfiles` mount point is an internal container path - your repository can have any name locally
- The repository is mounted read-only to ensure tests never modify your files
- Each test runs in a fresh container with no state persisted between runs

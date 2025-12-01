# Dotfiles Testing

Lightweight Docker-based tests for the chezmoi source. The harness builds a minimal Ubuntu image, applies the dotfiles, re-applies to ensure idempotency, and asserts a few key installs.

## Prerequisites

- Docker installed and running

## Run the Test

From the repository root:

```bash
./tests/test.sh
```

## What It Does

1) Builds an Ubuntu 22.04 image with curl, git, sudo, and chezmoi preinstalled under a non-root user (`testuser`).
2) Runs `tests/container-test.sh` inside the container, which:
   - Copies the repo to `~/.local/share/chezmoi`
   - Runs `chezmoi apply`, then re-runs to check idempotency and a clean `chezmoi diff`
   - Asserts key artifacts:
     - Starship installed
     - Antidote installed
     - `.zshrc` present
     - `~/.config/starship.toml` present
     - MesloLGS Nerd Font (>=4 variants) in Linux/macOS font paths
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

==> Verification Results:
  ✓ Starship installed (starship X.Y.Z)
  ✓ Antidote installed
  ✓ .zshrc installed
  ✓ Starship config installed
  ✓ MesloLGS Nerd Font installed (4 variants)

==> Summary: 7 passed, 0 failed
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
chezmoi apply -v  # idempotency check
chezmoi diff      # should be empty
```

Verify installations:

```bash
starship --version
ls ~/.antidote/
ls ~/.local/share/fonts/
ls ~/.config/starship.toml
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

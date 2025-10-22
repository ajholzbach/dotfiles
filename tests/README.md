# Dotfiles Testing

Tests the dotfiles installation on Ubuntu Linux using Docker.

## Prerequisites

- Docker installed and running

## Run the Test

From the repository root:

```bash
./tests/test.sh
```

## What It Does

1. Builds an Ubuntu 22.04 Docker image with:
   - curl, git, and sudo installed
   - chezmoi pre-installed in user's PATH
   - Non-root user (testuser) for realistic testing

2. Runs the installation test:
   - Mounts your dotfiles repository into the container at `/dotfiles` (read-only)
   - Copies the repository to `~/.local/share/chezmoi` (chezmoi's source directory)
   - Runs `chezmoi apply` to install all dotfiles and execute scripts
   - Filters output to show only important installation messages

3. Verifies key components installed successfully:
   - **Starship**: Cross-shell prompt (with version info)
   - **Antidote**: Zsh plugin manager
   - **MesloLGS NF fonts**: All 4 font variants (Regular, Bold, Italic, Bold Italic)

4. Reports results:
   - Shows which components passed/failed with ✓/✗
   - Displays summary (e.g., "3 passed, 0 failed")
   - Exits with code 0 if all passed, code 1 if any failed

## Expected Output

```
Building Docker image...
Running chezmoi installation test...

==> Setting up chezmoi source directory...
==> Running chezmoi apply...
Installing MesloLGS NF fonts...
Installing starship with official installer...
Installing antidote zsh plugin manager...

==> Verification Results:
  ✓ Starship installed (starship 1.23.0)
  ✓ Antidote installed
  ✓ MesloLGS NF fonts installed (4 variants)

==> Summary: 3 passed, 0 failed
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
```

Verify installations:

```bash
starship --version
ls ~/.antidote/
ls ~/.local/share/fonts/
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

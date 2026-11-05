# Tests

Docker suites that install the dotfiles on a fresh system, apply again, and uninstall. [GitHub Actions](../.github/workflows/test.yml) runs every suite on each push and pull request, and weekly. It also runs [`macos-test.sh`](macos-test.sh) on a real macOS runner. That test changes the real home directory, so it runs only when `CI=true`.

## Run

Requires Docker and network access. On ARM hosts, the Arch and PowerShell suites need amd64 emulation, which Docker Desktop and OrbStack provide.

```sh
./tests/test.sh              # every suite
./tests/test.sh minimal      # one suite
```

| Suite | Base | Covers |
| --- | --- | --- |
| `minimal` | Ubuntu 24.04 | Bash and Starship with no optional tools and no sudo |
| `ubuntu` | Ubuntu 24.04 | Every optional shell and tool, Antidote, and the Fish theme |
| `arch` | Arch Linux | The `ubuntu` checks on Arch |
| `tools-ubuntu` | Ubuntu 24.04 | The tools install with `mise bootstrap` and apt |
| `tools-arch` | Arch Linux | The tools install with `mise bootstrap` and pacman |
| `powershell` | PowerShell on Ubuntu 24.04 | The Windows scripts, with WinGet and Scoop mocks |

Each Linux suite checks that the restore point captures the original files, a second apply changes nothing, and uninstall restores the originals.

## Rules

- Every script in `home/.chezmoiscripts/` needs an entry in [`script-coverage.tsv`](script-coverage.tsv). The runner fails before it builds an image when one is missing.
- The runner mounts a read-only copy of the tracked and new files at `/dotfiles`. It never mounts `.git`, ignored files, or `local-env` files, and it never forwards credentials into a container.
- The suites use the latest chezmoi, Starship, Antidote, mise, and Fisher releases. Rerun a suite once to rule out a network failure.

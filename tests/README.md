# Docker test gate

The local Docker suite is the required validation gate for this repository. It tests a fresh installation, a full idempotent re-apply, and restoration of the pre-install state. Every active template in `home/.chezmoiscripts/` must have an entry in the script coverage manifest or the runner fails before building an image.

## Prerequisites

- Docker with a running daemon
- Network access while resolving the current chezmoi, Python, Starship, Antidote, and zsh plugin releases
- amd64 emulation for the Arch and PowerShell images when the host is ARM; Docker Desktop and OrbStack normally provide it

## Run

From the repository root:

```sh
./tests/test.sh all          # complete required gate
./tests/test.sh minimal      # no optional shells or tools
./tests/test.sh ubuntu       # Ubuntu compatibility image
./tests/test.sh arch         # Arch compatibility image
./tests/test.sh powershell   # rendered Windows scripts under pwsh
```

Running `./tests/test.sh` without a selector is equivalent to `all`.

## Matrix

| Suite | Base | Purpose |
|---|---|---|
| `minimal` | Ubuntu 24.04 | Proves Bash plus Starship works without Fish, zsh, Xonsh, mise, bat, zoxide, fzf, tmux, Vim, or passwordless sudo |
| `ubuntu` | Ubuntu 24.04 | Installs Antidote, persists the Fish theme, starts the optional shell setup, and loads Vim/tmux configuration |
| `arch` | Arch Linux | Exercises the same optional-tool and shell-setup path against rolling Arch userland and pacman package names |
| `powershell` | PowerShell on Ubuntu 24.04 | Renders Windows-only templates and tests them with isolated WinGet/Scoop mocks and Windows-like profile fixtures |

The PowerShell image is deterministic compatibility coverage for Windows scripts. It does not claim to emulate the Windows kernel, registry, ACLs, path rules, or native package managers; a real Windows smoke test remains appropriate before a release that materially changes Windows behavior.

## What the Linux suites prove

Each Linux integration container:

1. Starts with pre-existing `.bashrc`, `.profile`, Git ignore, and symlink fixtures.
2. Runs `chezmoi init --apply file:///dotfiles` as an unprivileged user, invoking the freshly installed executable by absolute path while its install directory is absent from `PATH`. This mirrors the boundary used by the documented one-line installer.
3. Verifies the restore-point manifests before checking managed output.
4. Verifies working Starship and conditional Antidote installations with ownership tracking.
5. Verifies Fish theme persistence, then starts every optional shell/tool available in that image.
6. Runs a second ordinary `chezmoi apply` with scripts enabled.
7. Requires a clean managed-file diff after the second apply. Scripts are excluded only from this diff display because ordinary `run_` scripts are expected to appear as runnable every time; they are included in both actual applies.
8. Runs uninstall first as a dry run and then for real.
9. Verifies byte-for-byte content, mode, symlink, and Fish-color restoration; newly managed targets and installer-owned Starship and Antidote must be gone.

The minimal image also asserts that the dotfiles neither require nor install optional tools.
Git is present only because the isolated local repository uses a `file://` clone;
chezmoi's built-in Git covers the documented HTTPS bootstrap when an external
Git command is unavailable.

## What the PowerShell suite proves

The PowerShell suite renders templates with `.chezmoi.os` set to `windows`, then covers:

- restore-point creation for pre-existing and absent targets
- Starship package-manager arguments and executable validation
- package-manager ownership tracking and uninstall behavior
- both PowerShell profile locations
- preservation of content outside the managed marker block
- repeated execution and duplicate-block repair
- rejection of malformed marker state
- restoration via `uninstall.ps1`

## Test isolation

The runner creates a temporary, allow-listed Git repository containing only the chezmoi source, uninstall helpers, and tests. The staged repository is mounted read-only at `/dotfiles`.

The host repository's `.git` directory, ignored files, editor metadata, and environment tokens are not mounted or forwarded. This is intentional: installation scripts and downloaded programs inside a test container must never receive the host's GitHub token. Unignored files in the install/test surface—including new work in progress—are staged because they are potential commit contents and must be exercised by the gate.

Known machine-local `local-env` source names are denied even if they have been
force-added to Git. Store credentials only in the unmanaged destination files
documented in the main README.

The temporary repository and each test container are removed automatically. Docker images remain cached to make repeated runs faster. Every runner invocation pulls fresh upstream base metadata and supplies a unique cache key to the chezmoi installer layer. That forces a fresh download of the current chezmoi release and, in the optional-tool images, fresh resolution of the unpinned Xonsh and Catppuccin Python packages without rebuilding earlier operating-system package layers unnecessarily.

The managed source intentionally has no `.chezmoiversion` compatibility pin. Running the gate against the current chezmoi release makes upstream compatibility changes visible before the dotfiles are pushed.

## Adding or changing a script

When adding or renaming anything under `home/.chezmoiscripts/`:

1. Add or update its coverage-manifest entry.
2. Add success, already-satisfied, failure, idempotency, and restoration cases appropriate to its side effects.
3. Run the narrow suite while iterating.
4. Run `./tests/test.sh all` before pushing.

The full gate deliberately includes scripts on the second apply. Excluding scripts would test only file rendering, not the idempotency requirement that applies to every chezmoi script.

## Troubleshooting

If Docker is unavailable, start Docker Desktop, OrbStack, or the system Docker daemon and rerun the command.

If Arch or PowerShell reports an unsupported platform or an exec-format error on an ARM host, enable amd64 emulation in the container runtime. Both suites explicitly request `linux/amd64` for consistent behavior across hosts.

If an upstream build or download fails, rerun the same selector to distinguish a transient registry/network issue from a repository failure. Do not work around failures by forwarding personal credentials into the container.

All selectors exit nonzero on failure, so the complete gate can be used directly by CI or a local pre-push workflow:

```sh
./tests/test.sh all
```

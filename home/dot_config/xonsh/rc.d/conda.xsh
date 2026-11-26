"""Conda integration. Lazy-loads the xonsh hook to keep startup fast.

On first `conda` use, sources the slow `conda shell.xonsh hook`, which
installs the real `conda` alias. Until then:
- condabin/ is on PATH so `conda`, `mamba`, etc. are callable as binaries
- a filesystem-based completer makes `conda activate <TAB>` work
- a lazy shim handles `conda` itself

`mamba activate` falls through to the binary and fails. Use
`conda activate`. The mamba 2.x xonsh hook only registers completers, and a
subprocess cannot change the environment of the parent shell.
"""

import os
import subprocess
import sys


def _find_conda():
    """Return (root, conda_binary_path) or (None, None)."""
    candidates = []
    if sys.platform == 'darwin':
        candidates += [
            '/opt/homebrew/Caskroom/miniforge/base',
            '/opt/homebrew/Caskroom/miniconda/base',
            '/usr/local/Caskroom/miniforge/base',
            '/usr/local/Caskroom/miniconda/base',
        ]
    candidates += [
        os.path.expanduser('~/miniforge3'),
        os.path.expanduser('~/miniconda3'),
        os.path.expanduser('~/anaconda3'),
    ]
    if sys.platform != 'win32':
        candidates += ['/opt/miniforge3', '/opt/miniconda3', '/opt/conda']
    bin_name = 'conda.bat' if sys.platform == 'win32' else 'conda'
    for root in candidates:
        binary = os.path.join(root, 'condabin', bin_name)
        if os.path.isfile(binary):
            return root, binary
    return None, None


def _build_conda_integration(conda_root, conda_bin):
    # The module deletes its globals, and FuncAlias rewrites signatures
    envs_dir = os.path.join(conda_root, 'envs')

    def register_completer():
        # conda's completer imports conda, which fails in xonsh's uv tool env
        def _conda_completer(prefix, line, start, end, ctx, _envs_dir=envs_dir):
            args = line.split(' ')
            if not args or args[0] != 'conda':
                return None
            possible = set()
            if len(args) == 2:
                possible = {
                    'activate', 'deactivate', 'install', 'remove', 'uninstall',
                    'update', 'upgrade', 'list', 'search', 'info', 'clean',
                    'config', 'create', 'env', 'run', 'init',
                    '-h', '--help', '-V', '--version',
                }
            elif len(args) == 3 and args[1] in ('activate', 'env'):
                if args[1] == 'env':
                    possible = {'list', 'create', 'remove', 'export', 'update'}
                elif os.path.isdir(_envs_dir):
                    possible = {
                        d for d in os.listdir(_envs_dir)
                        if os.path.isdir(os.path.join(_envs_dir, d))
                    }
            return {p for p in possible if p.startswith(prefix)}

        __xonsh__.completers['conda'] = _conda_completer
        __xonsh__.completers.move_to_end('conda', last=False)

    def lazy_conda(args):
        del aliases['conda']
        try:
            result = subprocess.run(
                [conda_bin, 'shell.xonsh', 'hook'],
                check=False,
                capture_output=True,
                text=True,
            )
        except OSError:
            aliases['conda'] = lazy_conda
            return 1
        if result.returncode != 0 or not result.stdout.strip():
            aliases['conda'] = lazy_conda
            return result.returncode or 1
        hook = result.stdout
        # conda activate fails when it runs inside this function
        lines = hook.strip().splitlines()
        if lines and lines[-1].strip().startswith('conda activate'):
            lines = lines[:-1]
        try:
            execx('\n'.join(lines))
        except Exception:
            aliases['conda'] = lazy_conda
            return 1
        # The hook replaced the completer with a broken one
        register_completer()
        real_conda = aliases.get('conda')
        if real_conda is None or real_conda is lazy_conda:
            aliases['conda'] = lazy_conda
            return 1
        return real_conda(args)

    return register_completer, lazy_conda


_conda_root, _conda_bin = _find_conda()

if _conda_root is not None:
    # Append condabin for now, and let the conda hook move it to the front when conda loads
    _condabin = os.path.join(_conda_root, 'condabin')
    if _condabin not in $PATH:
        $PATH.append(_condabin)
    del _condabin

    _register, _lazy = _build_conda_integration(_conda_root, _conda_bin)
    _register()
    aliases['conda'] = _lazy
    del _register, _lazy

del _conda_root, _conda_bin, _find_conda, _build_conda_integration

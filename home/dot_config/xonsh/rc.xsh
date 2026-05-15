"""Xonsh rc, modeled on ~/.config/fish/config.fish.

Installed via: `uv tool install 'xonsh[full]'`.
Binary at:     ~/.local/bin/xonsh
Loaded from:   ~/.config/xonsh/rc.xsh   (XDG path, see https://xon.sh/xonshrc.html)
"""

import os

# -- XDG and PATH ------------------------------------------------------------

$XDG_CONFIG_HOME = ${...}.get('XDG_CONFIG_HOME', $HOME + '/.config')

# $PATH is an EnvPath (list-like). `.insert` and `in` work like on a list.
for _p in ('/usr/local/bin', $HOME + '/.local/bin'):
    if _p not in $PATH:
        $PATH.insert(0, _p)

# Homebrew on Apple Silicon. Mirrors the conditional from the fish config.
if os.path.exists('/opt/homebrew/bin/brew'):
    for _p in ('/opt/homebrew/bin', '/opt/homebrew/sbin'):
        if _p not in $PATH:
            $PATH.insert(0, _p)
    $HOMEBREW_DOWNLOAD_CONCURRENCY = ${...}.get('HOMEBREW_DOWNLOAD_CONCURRENCY', 'auto')

# -- Shell behavior ----------------------------------------------------------

# Fish auto-cds when you type a bare directory name; match that.
$AUTO_CD = True
# Keep os.environ in sync with $VARS so Python subprocesses see edits.
$UPDATE_OS_ENVIRON = True
# Catppuccin Mocha pygments theme. Requires `catppuccin[pygments]` in the
# xonsh tool env: `uv tool install 'xonsh[full]' --with 'catppuccin[pygments]'`.
$XONSH_COLOR_STYLE = 'catppuccin-mocha'

# Fish-like command validity coloring. Catppuccin Mocha's stock mapping is
# backwards for shells (valid command -> red, invalid -> default text), because
# xonsh's lexer uses Name.Builtin for resolved commands and Error for unresolved.
# Swap them to Catppuccin blue (valid) and red (invalid).
$XONSH_STYLE_OVERRIDES = {
    'Token.Name.Builtin': '#89b4fa noitalic',
    'Token.Error': '#f38ba8 bold',
}

# -- Interactive integrations ------------------------------------------------

if $XONSH_INTERACTIVE:
    # Starship prompt
    if !(which starship).returncode == 0:
        execx($(starship init xonsh))

    # Mise runtime version manager
    if !(which mise).returncode == 0:
        execx($(mise activate xonsh))

    # OrbStack: init.bash only adds ~/.orbstack/bin to PATH and sources
    # bash completions (irrelevant to xonsh). Do the PATH part directly.
    _orb_bin = $HOME + '/.orbstack/bin'
    if os.path.isdir(_orb_bin) and _orb_bin not in $PATH:
        $PATH.append(_orb_bin)
    del _orb_bin

    # Zoxide as `cd` (fish equivalent: `zoxide init --cmd cd fish | source`)
    if !(which zoxide).returncode == 0:
        execx($(zoxide init xonsh --cmd cd))

    # bat as `cat` (fish equivalent: cat.fish lazy shim)
    if !(which bat).returncode == 0:
        aliases['cat'] = ['bat', '--paging=never', '--style=plain', '--color=auto']

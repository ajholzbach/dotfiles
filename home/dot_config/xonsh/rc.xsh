r"""Xonsh rc, portable across macOS, Linux, and Windows.

Install / rebuild / add packages: see docs/tools.md in the repo.
"""

import os
import shutil
import sys

$XDG_CONFIG_HOME = ${...}.get('XDG_CONFIG_HOME', f'{$HOME}/.config')
$STARSHIP_CONFIG = ${...}.get('STARSHIP_CONFIG', f'{$HOME}/.config/starship.toml')
$BAT_CONFIG_PATH = ${...}.get('BAT_CONFIG_PATH', f'{$HOME}/.config/bat/config')

# local-env.sh is an untracked file for per-machine values, and xonsh reads the Bash version
if os.path.isfile(f'{$HOME}/.config/local-env.sh'):
    source-bash @(f'{$HOME}/.config/local-env.sh')

for _user_bin in (f'{$HOME}/bin', f'{$HOME}/.local/bin'):
    if os.path.isdir(_user_bin) and _user_bin not in $PATH:
        $PATH.insert(0, _user_bin)
del _user_bin

if sys.platform != 'win32' and '/usr/local/bin' not in $PATH:
    $PATH.insert(0, '/usr/local/bin')


def _add_homebrew_to_path():
    for brew_bin in (
        '/opt/homebrew/bin/brew',
        '/usr/local/bin/brew',
        '/home/linuxbrew/.linuxbrew/bin/brew',
    ):
        if os.path.isfile(brew_bin) and os.access(brew_bin, os.X_OK):
            prefix = os.path.dirname(os.path.dirname(brew_bin))
            for p in (f'{prefix}/bin', f'{prefix}/sbin'):
                if p not in $PATH:
                    $PATH.insert(0, p)
            $HOMEBREW_DOWNLOAD_CONCURRENCY = ${...}.get('HOMEBREW_DOWNLOAD_CONCURRENCY', 'auto')
            return


_add_homebrew_to_path()
del _add_homebrew_to_path

$XONSH_HISTORY_BACKEND = 'sqlite'
$ENABLE_ASYNC_PROMPT = True
$XONSH_COLOR_STYLE = 'catppuccin-mocha'
# PTK rounds the Catppuccin colors to 256 colors by default
$PROMPT_TOOLKIT_COLOR_DEPTH = 'DEPTH_24_BIT'

# The catppuccin-mocha style does not define these tokens
$XONSH_STYLE_OVERRIDES = {
    'Token.Name.Builtin': '#89b4fa noitalic',
    'Token.Error': '#f38ba8 bold',
    # xonsh builds the combined LS_COLORS tokens from these base tokens
    'Token.Color.BLACK':         '#45475a',
    'Token.Color.RED':           '#f38ba8',
    'Token.Color.GREEN':         '#a6e3a1',
    'Token.Color.YELLOW':        '#f9e2af',
    'Token.Color.BLUE':          '#89b4fa',
    'Token.Color.PURPLE':        '#cba6f7',
    'Token.Color.CYAN':          '#94e2d5',
    'Token.Color.WHITE':         '#cdd6f4',
    'Token.Color.BOLD_BLACK':    '#585b70 bold',
    'Token.Color.BOLD_RED':      '#f38ba8 bold',
    'Token.Color.BOLD_GREEN':    '#a6e3a1 bold',
    'Token.Color.BOLD_YELLOW':   '#f9e2af bold',
    'Token.Color.BOLD_BLUE':     '#89b4fa bold',
    'Token.Color.BOLD_PURPLE':   '#cba6f7 bold',
    'Token.Color.BOLD_CYAN':     '#89dceb bold',
    'Token.Color.BOLD_WHITE':    '#cdd6f4 bold',
    'Token.Color.BACKGROUND_BLACK':  'bg:#45475a',
    'Token.Color.BACKGROUND_RED':    'bg:#f38ba8',
    'Token.Color.BACKGROUND_GREEN':  'bg:#a6e3a1',
    'Token.Color.BACKGROUND_YELLOW': 'bg:#f9e2af',
    'Token.Color.BACKGROUND_BLUE':   'bg:#89b4fa',
    'Token.PTK.AutoSuggestion': '#6c7086',
    'Token.PTK.CompletionMenu': 'bg:#181825 #cdd6f4',
    'Token.PTK.CompletionMenu.Completion': 'bg:#181825 #cdd6f4',
    'Token.PTK.CompletionMenu.Completion.Current': 'bg:#89b4fa #11111b bold',
    'Token.PTK.Scrollbar.Background': 'bg:#181825',
    'Token.PTK.Scrollbar.Button': 'bg:#585b70',
}

if $XONSH_INTERACTIVE:
    $AUTO_CD = True
    $UPDATE_OS_ENVIRON = True

    # xonsh init resets the Color.* tokens to its defaults
    from xonsh.events import events

    @events.on_post_init
    def _reapply_style_overrides(**kw):
        try:
            styler = __xonsh__.shell.shell.styler
        except AttributeError:
            return
        styler.override($XONSH_STYLE_OVERRIDES)
        for k in [k for k in list(styler.trap) if 'Color' in str(k)
                  and str(k) not in $XONSH_STYLE_OVERRIDES]:
            del styler.trap[k]
        styler.styles.maps[-1].colors.clear()
        from xonsh.pyghooks import color_token_by_name, file_color_tokens
        for code, xc in __xonsh__.env.get('LS_COLORS', {}).items():
            file_color_tokens[code] = color_token_by_name(xc, styler.styles)

    if shutil.which('starship'):
        execx($(starship init xonsh))

    if shutil.which('mise'):
        execx($(mise activate xonsh))

    if sys.platform == 'darwin':
        _orb_bin = f'{$HOME}/.orbstack/bin'
        if os.path.isdir(_orb_bin) and _orb_bin not in $PATH:
            $PATH.append(_orb_bin)
        del _orb_bin

    if shutil.which('zoxide'):
        execx($(zoxide init xonsh --cmd cd))

    if shutil.which('bat'):
        aliases['cat'] = ['bat', '--paging=never', '--style=plain', '--color=auto']

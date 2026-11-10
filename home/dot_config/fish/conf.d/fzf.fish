status is-interactive; or exit

# fzf --fish defines the fzf key bindings, but takes 6 ms at startup
# Remove the placeholder keys, run fzf --fish, then run the pressed widget
function __fzf_load -a widget
    functions -e __fzf_load __fzf_check
    for mode in default insert
        bind -M $mode -e \cr \ct \ec
        bind -M $mode -e $__fzf_load_btab
    end
    set -e __fzf_load_btab
    command -q fzf; and fzf --fish | source
    # __fzf_check calls this function with no widget
    set -q widget[1]; or return
    if functions -q $widget
        $widget
    else
        # The widget is missing when fzf is not installed
        commandline -f repaint
    end
end

# Fish 3 has no shift-tab key name
# Pick the Shift+Tab key name for this fish version
if string match -qr -- '^\d\d+|^[4-9]' $version
    set -g __fzf_load_btab shift-tab
else
    set -g __fzf_load_btab -k btab
end
# Bind the fzf keys to __fzf_load until fzf --fish runs
for mode in default insert
    bind -M $mode \cr '__fzf_load fzf-history-widget'
    bind -M $mode \ct '__fzf_load fzf-file-widget'
    bind -M $mode \ec '__fzf_load fzf-cd-widget'
    bind -M $mode $__fzf_load_btab '__fzf_load fzf_complete'
end

# conf.d runs before config.fish adds Homebrew and ~/.local/bin to PATH
# At the first prompt, remove the placeholder keys if fzf is still missing
function __fzf_check --on-event fish_prompt
    functions -e __fzf_check
    command -q fzf; or __fzf_load
end

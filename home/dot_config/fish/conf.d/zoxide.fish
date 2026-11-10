status is-interactive; or exit

# zoxide init defines the zoxide cd, but takes 5 ms at startup
# Run zoxide init on the first cd or cd completion
function __zoxide_load
    functions -e __zoxide_load __zoxide_check cd
    complete -e -c __zoxide_z
    command -q zoxide; and zoxide init --cmd cd fish | source
    functions -q cd; and return
    # zoxide is missing or zoxide init failed
    # Load the cd function and cd completions that fish ships
    complete -e -c cd
    __source_fish_function cd completions
    __source_fish_function cd
    return 1
end

# Without the wrap, fish marks zoxide queries as bad paths
# Load zoxide on the first cd, then run the zoxide cd
function cd --wraps __zoxide_z
    functions -e cd
    __zoxide_load
    cd $argv
end
# Load zoxide on the first cd completion
complete -c __zoxide_z -f -a '(__zoxide_load; and __zoxide_z_complete)'

# conf.d runs before config.fish adds Homebrew and ~/.local/bin to PATH
# At the first prompt, restore the fish cd if zoxide is still missing
function __zoxide_check --on-event fish_prompt
    functions -e __zoxide_check
    command -q zoxide; or __zoxide_load
end

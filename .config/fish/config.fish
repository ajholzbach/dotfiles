if status is-interactive
    starship init fish | source
    enable_transience
    if type -q zoxide
        zoxide init --cmd cd fish | source
    end
end

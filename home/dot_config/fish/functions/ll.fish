function ll --wraps 'eza -l'
    functions --erase ll
    if command -q eza
        alias ll='eza -l --group-directories-first --icons=auto'
    else
        __source_fish_function ll
    end
    ll $argv
end

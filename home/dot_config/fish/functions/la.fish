function la --wraps 'eza -a'
    functions --erase la
    if command -q eza
        alias la='eza -a --group-directories-first --icons=auto'
    else
        __source_fish_function la
    end
    la $argv
end

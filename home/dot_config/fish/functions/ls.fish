function ls --wraps ls
    functions --erase ls
    if command -q eza
        alias ls='eza --group-directories-first --icons=auto'
    else
        __source_fish_function ls
    end
    ls $argv
end

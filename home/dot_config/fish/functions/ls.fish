function ls --wraps ls
    functions --erase ls
    if type -q eza
        alias ls='eza --color=always --group-directories-first --icons=always'
    end
    ls $argv
end

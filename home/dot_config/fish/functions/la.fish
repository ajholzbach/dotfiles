function la --wraps eza
    functions --erase la
    if type -q eza
        alias la='eza -a --color=always --group-directories-first --icons=always'
    end
    la $argv
end

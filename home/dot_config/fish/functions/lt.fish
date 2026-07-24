function lt --wraps eza
    functions --erase lt
    if type -q eza
        alias lt='eza -aT --color=always --group-directories-first --icons=always'
    end
    lt $argv
end

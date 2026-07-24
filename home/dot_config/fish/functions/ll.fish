function ll --wraps eza
    functions --erase ll
    if type -q eza
        alias ll='eza -l --color=always --group-directories-first --icons=always'
    end
    ll $argv
end

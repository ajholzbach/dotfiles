function lt --wraps 'eza -aT'
    if command -q eza
        functions --erase lt
        alias lt='eza -aT --group-directories-first --icons=auto'
    else if command -q tree
        functions --erase lt
        alias lt='tree -a'
    else
        echo "lt: needs eza or tree" >&2
        return 127
    end
    lt $argv
end

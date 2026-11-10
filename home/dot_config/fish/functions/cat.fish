function cat --wraps cat
    functions --erase cat
    if command -q bat
        alias cat='bat --plain'
    end
    cat $argv
end

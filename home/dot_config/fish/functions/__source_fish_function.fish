function __source_fish_function -a name dir -d "Load Fish's own copy of a function or completion that a plugin replaced"
    set -q dir[1]; or set dir functions
    if status get-file $dir/$name.fish &>/dev/null
        status get-file $dir/$name.fish | source
    else if test -f $__fish_data_dir/$dir/$name.fish
        source $__fish_data_dir/$dir/$name.fish
    end
end

# Tool init commands print the same script each time, but take 5 to 10 ms each
# Source the script from a cache file, and rebuild the file when the tool binary changes
function __dotfiles_source_init -d "Source the script that a tool init command prints, from a cache file"
    set -l bin (command -s $argv[1]); or return
    set -l cache $__fish_user_data_dir/$argv[1]-init.fish
    set -l key "# "(path resolve $bin)" "(path mtime $bin)
    set -l line
    test -f $cache; and read line <$cache
    if test "$line" != "$key"
        set -l init ($bin $argv[2..] 2>/dev/null); or return
        set -q init[1]; or return
        mkdir -p $__fish_user_data_dir
        # Another shell can start while this shell writes the cache
        # Write a temp file, then rename the temp file to the cache file
        printf '%s\n' $key $init >$cache.$fish_pid; and mv $cache.$fish_pid $cache
    end
    source $cache
end

# Tool init commands are slow, and they print the same script each time
# --from LINE caches the script from LINE on, for a script whose first lines depend on the environment
# --env NAME=VALUE sets a variable only for the command that builds the cache
function __dotfiles_source_init -d "Source the script that a tool init command prints, from a cache file"
    set -l call $argv
    argparse --stop-nonopt 'from=' 'env=+' -- $argv; or return
    set -l bin (command -s $argv[1]); or return
    set -l cache $__fish_user_data_dir/$argv[1]-init.fish
    set -l key (string join -- " " "#" (path resolve $bin) (path mtime $bin (status current-filename)) $call)
    set -l cached_key
    test -f $cache; and read cached_key <$cache
    if test "$cached_key" != "$key"
        set -l script (env $_flag_env $bin $argv[2..] 2>/dev/null); or return
        set -q script[1]; or return
        if set -q _flag_from
            # A script without LINE has a format that this function does not know
            if not set -l start (contains -i -- $_flag_from $script)
                printf '%s\n' $script | source
                return
            end
            set script $script[$start..]
        end
        mkdir -p $__fish_user_data_dir
        # A shell that starts during the write must never read a partial cache
        if not printf '%s\n' $key $script >$cache.$fish_pid; or not mv $cache.$fish_pid $cache
            # Without a new cache, source would read a stale cache or none
            rm -f $cache.$fish_pid
            printf '%s\n' $script | source
            return
        end
    end
    source $cache
end

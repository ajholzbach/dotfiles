# Add Homebrew to PATH if it exists
if test -x /opt/homebrew/bin/brew
    contains /opt/homebrew/bin $fish_user_paths; or fish_add_path -U /opt/homebrew/bin
end

if status is-interactive
    # starship.rs prompt
    if type -q starship
        # starship init fish | source
        echo "source (starship init fish --print-full-init | psub)" | source
        enable_transience
    end
end

# Set XDG_CONFIG_HOME if not already set
if not set -q XDG_CONFIG_HOME
    set -x XDG_CONFIG_HOME $HOME/.config
end

# Add Homebrew to PATH if it exists
if test -x /opt/homebrew/bin/brew
    contains /opt/homebrew/bin $fish_user_paths; or fish_add_path -U /opt/homebrew/bin
end

if status is-interactive
    # Fisher setup
    if not functions -q fisher
        fisher_setup
    end
    # starship.rs prompt
    if type -q starship
        # starship init fish | source
        echo "source (starship init fish --print-full-init | psub)" | source
        enable_transience
    end
end

# Set XDG_CONFIG_HOME
if not set -q XDG_CONFIG_HOME
    set -xg XDG_CONFIG_HOME $HOME/.config
end

# Add to PATH
contains /usr/local/bin $fish_user_paths; or fish_add_path -U /usr/local/bin
contains $HOME/.local/bin $fish_user_paths; or fish_add_path -U $HOME/.local/bin

# Add Homebrew to PATH if installed
if test -x /opt/homebrew/bin/brew
    contains /opt/homebrew/bin $fish_user_paths; or fish_add_path -U /opt/homebrew/bin
    # Set concurrent downloads for Homebrew if not already set
    if not set -q HOMEBREW_DOWNLOAD_CONCURRENCY
        set -xg HOMEBREW_DOWNLOAD_CONCURRENCY auto
    end
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
    # mise shell integration
    if type -q mise
        # Turn off auto-activation of mise environment to avoid double activation
        if not set -q MISE_FISH_AUTO_ACTIVATE
            set -Ux MISE_FISH_AUTO_ACTIVATE 0
        end
        mise activate fish | source
    end
end

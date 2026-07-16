# Set XDG_CONFIG_HOME
if not set -q XDG_CONFIG_HOME
    set -xg XDG_CONFIG_HOME $HOME/.config
end

if not set -q STARSHIP_CONFIG
    set -xg STARSHIP_CONFIG $HOME/.config/starship.toml
end

if not set -q BAT_CONFIG_PATH
    set -xg BAT_CONFIG_PATH $HOME/.config/bat/config
end

# Per-machine env (untracked)
if not set -q DOTFILES_LOADING_LOCAL_ENV; and test -f $HOME/.config/local-env.fish
    set -g DOTFILES_LOADING_LOCAL_ENV 1
    source $HOME/.config/local-env.fish
    set -e DOTFILES_LOADING_LOCAL_ENV
end

# Add to PATH
test -d /usr/local/bin; and fish_add_path -g /usr/local/bin
test -d $HOME/bin; and fish_add_path -g $HOME/bin
test -d $HOME/.local/bin; and fish_add_path -g $HOME/.local/bin

# Add Homebrew to PATH if installed
if test -x /opt/homebrew/bin/brew
    fish_add_path -g /opt/homebrew/bin /opt/homebrew/sbin
    # Set concurrent downloads for Homebrew if not already set
    if not set -q HOMEBREW_DOWNLOAD_CONCURRENCY
        set -xg HOMEBREW_DOWNLOAD_CONCURRENCY auto
    end
end

if test -x /usr/local/bin/brew
    fish_add_path -g /usr/local/bin /usr/local/sbin
    if not set -q HOMEBREW_DOWNLOAD_CONCURRENCY
        set -xg HOMEBREW_DOWNLOAD_CONCURRENCY auto
    end
end

if test -x /home/linuxbrew/.linuxbrew/bin/brew
    fish_add_path -g /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin
    if not set -q HOMEBREW_DOWNLOAD_CONCURRENCY
        set -xg HOMEBREW_DOWNLOAD_CONCURRENCY auto
    end
end

if status is-interactive
    # Silence fish's built-in welcome banner
    set -g fish_greeting ""

    # starship.rs prompt
    if type -q starship
        starship init fish --print-full-init | source
        functions -q enable_transience; and enable_transience
    end
    # mise shell integration
    if type -q mise
        # Turn off auto-activation of mise environment to avoid double activation
        if not set -q MISE_FISH_AUTO_ACTIVATE
            set -gx MISE_FISH_AUTO_ACTIVATE 0
        end
        mise activate fish | source
    end
    # OrbStack shell integration
    if type -q orb
        source ~/.orbstack/shell/init2.fish 2>/dev/null || :
    end
end

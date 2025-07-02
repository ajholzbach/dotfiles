if status is-interactive
    # starship.rs prompt
    if type -q starship
        # starship init fish | source
        echo "source (starship init fish --print-full-init | psub)" | source
        enable_transience
    end
end

function fisher_setup --description 'Sync Fisher plugins and apply the managed theme'
    if not functions -q fisher
        echo "fisher is not installed; rerun chezmoi apply after installing fish" >&2
        return 1
    end

    fisher update

    if test -f "$XDG_CONFIG_HOME/fish/themes/Catppuccin Mocha.theme"
        echo y | fish_config theme save "Catppuccin Mocha" > /dev/null
    end
end

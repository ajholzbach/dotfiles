function fisher_setup --description 'Sync Fisher plugins and apply the managed theme'
    if not functions -q fisher
        echo "Fisher is not installed; install Fisher, then run fisher_setup again" >&2
        return 1
    end

    fisher update; or return 1

    if test -f "$XDG_CONFIG_HOME/fish/themes/Catppuccin Mocha.theme"
        echo y | fish_config theme save "Catppuccin Mocha" > /dev/null; or return 1
    end
end

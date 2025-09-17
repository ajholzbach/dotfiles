function fisher_setup --description 'Bootstrap Fisher and install plugins'
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update
    if test -f "$XDG_CONFIG_HOME/fish/themes/Catppuccin Mocha.theme"
        echo y | fish_config theme save "Catppuccin Mocha" > /dev/null
    end
end

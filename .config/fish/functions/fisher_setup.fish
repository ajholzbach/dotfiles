function fisher_setup --description 'Bootstrap Fisher and plugins'
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update
    if test -f "$XDG_CONFIG_HOME/fish/themes/Catppuccin Mocha.theme"
        fish_config theme save "Catppuccin Mocha"
    end
end

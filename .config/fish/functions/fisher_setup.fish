function fisher_setup --description 'Bootstrap Fisher and plugins'
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update
end

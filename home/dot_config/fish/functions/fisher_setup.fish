function fisher_setup --description 'Sync optional Fisher plugins'
    if not functions -q fisher
        echo "Fisher is not installed; install Fisher, then run fisher_setup again" >&2
        return 1
    end
    fisher update
end

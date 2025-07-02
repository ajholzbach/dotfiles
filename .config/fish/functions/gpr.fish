function gpr --wraps 'git pull --rebase'
    git pull --rebase $argv
end

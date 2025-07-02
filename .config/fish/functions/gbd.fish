function gbd --wraps 'git branch --delete'
    git branch --delete $argv
end

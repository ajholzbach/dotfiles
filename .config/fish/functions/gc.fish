function gc --wraps 'git commit'
    git commit --verbose $argv
end

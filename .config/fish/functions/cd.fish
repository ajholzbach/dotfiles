function cd --wraps cd
    functions --erase cd
    if type -q zoxide
        zoxide init --cmd cd fish | source
    end
    cd $argv
end

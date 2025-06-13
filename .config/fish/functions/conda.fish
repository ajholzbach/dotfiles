function conda
    functions --erase conda
    # >>> conda initialize >>>
    if test -f /opt/homebrew/Caskroom/miniconda/base/bin/conda
        eval /opt/homebrew/Caskroom/miniconda/base/bin/conda "shell.fish" "hook" | source
        conda $argv
    else
        if test -f "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
            . "/opt/homebrew/Caskroom/miniconda/base/etc/fish/conf.d/conda.fish"
        else
            set -x PATH "/opt/homebrew/Caskroom/miniconda/base/bin" $PATH
        end
    end
    # <<< conda initialize <<<
end

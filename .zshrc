# """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
#                 ███████╗███████╗██╗  ██╗██████╗  ██████╗
#                 ╚══███╔╝██╔════╝██║  ██║██╔══██╗██╔════╝
#                   ███╔╝ ███████╗███████║██████╔╝██║
#                  ███╔╝  ╚════██║██╔══██║██╔══██╗██║
#                 ███████╗███████║██║  ██║██║  ██║╚██████╗
#                 ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝
# """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Alias 'gup' (for git update) will pull latest changes into main branch and then rebase into current branch
alias gup='
GIT_CURRENT_BRANCH=$(git_current_branch);
GIT_MAIN_BRANCH=$(git_main_branch);

if git diff-index --quiet HEAD --; then
  echo "No changes to stash";
else
  echo "Stashing changes...";
  git stash push -m "pre-merge stash" --include-untracked;
  STASHED=true;
fi;

echo "--------------------";
echo "Switching to '\''$GIT_MAIN_BRANCH'\''...";
git switch "$GIT_MAIN_BRANCH";

echo "--------------------";
echo "Pulling latest changes into '\''$GIT_MAIN_BRANCH'\''...";
git pull --rebase --autostash;

echo "--------------------";
echo "Switching back to '\''$GIT_CURRENT_BRANCH'\''...";
git switch "$GIT_CURRENT_BRANCH";

echo "--------------------";
echo "Merging '\''$GIT_MAIN_BRANCH'\'' into '\''$GIT_CURRENT_BRANCH'\''...";
git merge "$GIT_MAIN_BRANCH";

if [ "$STASHED" = true ]; then
  echo "--------------------";
  echo "Applying stashed changes...";
  git stash pop;
fi;

unset GIT_CURRENT_BRANCH GIT_MAIN_BRANCH STASHED;
echo "--------------------";
echo "Update and merge complete.";
'

if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Don't activate conda base env by default to speed up shell startup
export CONDA_AUTO_ACTIVATE_BASE=false

# OSX
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Lazy-load conda if installed
    if [ -d "/opt/homebrew/Caskroom/miniconda/base" ]; then
        conda() {
        unset -f conda
        # >>> conda initialize >>>
        __conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        else
            if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
                . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
            else
                export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
            fi
        fi
        unset __conda_setup
        # <<< conda initialize <<<
        conda "$@"
        }
    fi

    # Lazy-load nvm if installed
    if [ -d "$HOME/.nvm" ] || [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
        nvm() {
        unset -f nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
        [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
        nvm "$@"
        }
    fi

    # Lazy-load pnpm if installed
    if command -v pnpm &> /dev/null || [ -d "$HOME/Library/pnpm" ]; then
        pnpm() {
        unset -f pnpm
        # pnpm
        export PNPM_HOME="$HOME/Library/pnpm"
        case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
        esac
        # pnpm end
        command pnpm "$@"
        }
    fi

    # Add alias for opening idea detached
    alias idead="open -a open -a IntelliJ\ IDEA"
fi

# # Set XDG_CONFIG_HOME if not already set
if [ -z "$XDG_CONFIG_HOME" ]; then
    export XDG_CONFIG_HOME="$HOME/.config"
fi

# Source .bash_profile if it exists
if [ -f ~/.bash_profile ]; then
    source ~/.bash_profile
fi

# Set default system editor to vim
export EDITOR=vim
export VISUAL=vim

# Load SDKMAN if installed
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Add zoxide if it exists
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
    alias cd='z'
    alias cdo='builtin cd'
fi

# Add bat alias if it exists
if command -v bat &> /dev/null; then
    alias cat='bat'
fi

# Add fzf if it exists and set catppuccin theme
if command -v fzf &> /dev/null; then
    source <(fzf --zsh)
    export FZF_DEFAULT_OPTS=" \
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
    --color=selected-bg:#45475a \
    --multi"
fi

# Compile zshrc if modified or doesn't exist
if [[ ! -f "$HOME/.zshrc.zwc" || "$HOME/.zshrc" -nt "$HOME/.zshrc.zwc" ]]; then
  zcompile "$HOME/.zshrc"
fi

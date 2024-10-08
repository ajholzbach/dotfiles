"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"               ██╗   ██╗██╗███╗   ███╗██████╗  ██████╗
"               ██║   ██║██║████╗ ████║██╔══██╗██╔════╝
"               ██║   ██║██║██╔████╔██║██████╔╝██║     
"               ╚██╗ ██╔╝██║██║╚██╔╝██║██╔══██╗██║     
"                ╚████╔╝ ██║██║ ╚═╝ ██║██║  ██║╚██████╗
"                 ╚═══╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Disable compatibility with vi which can cause unexpected issues.
set nocompatible

" Enable type file detection. Vim will be able to try to detect the type of file is use.
filetype on

" Load an indent file for the detected file type.
filetype indent on

" Use UTF-8 as the default encoding
set encoding=utf-8

" Enable mouse support.
set mouse=a

" Enable use of system clipboard.
set clipboard^=unnamed,unnamedplus

" Turn syntax highlighting on.
syntax enable

" Set the colorscheme to use.
colorscheme catppuccin_mocha

" Add numbers to the file.
set number

" Highlight cursor line underneath the cursor horizontally.
set cursorline

" Highlight matching brackets
set showmatch

" Set shift width to 4 spaces.
set shiftwidth=4

" Set tab width to 4 columns.
set tabstop=4

" Use tab characters when pressing tab.
set noexpandtab

" Set autoindent to automatically indent the next line.
set autoindent

" Backup files before overwriting them and delete backup on successful write.
set writebackup

" Do not let cursor scroll below or above N number of lines when scrolling.
set scrolloff=10

" Keep at least 10 columns to the side of the cursor
set sidescrolloff=10

" Do not wrap lines. Allow long lines to extend as far as the line goes.
set wrap

" While searching though a file incrementally highlight matching characters as you type.
set incsearch

" Ignore capital letters during search.
set ignorecase

" Override the ignorecase option if searching for capital letters.
" This will allow you to search specifically for capital letters.
set smartcase

" Show matching words during a search.
set showmatch

" Use highlighting when doing a search.
set hlsearch

" Set the commands to save in history default number is 20.
set history=1000

" Enable auto completion menu after pressing TAB.
set wildmenu

" Make wildmenu behave like similar to Bash completion.
set wildmode=list:longest

" Use syntax-based folding
set foldmethod=syntax

" Start editing with all folds open
set foldlevelstart=99

" Fix the backspace key
set backspace=indent,eol,start


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                   STATUSLINE CONFIGURATION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" This was made by Reddit user u/SamLovesNotion. Also with the help of - https://tdaly.co.uk/projects/vim-statusline-generator/ for learning the syntax.
" Slightly modified by ajholzbach to work with Catppuccin Mocha theme.

" Define color variables
let g:StslineColorGreen  = "#a6e3a1"  " Catppuccin Green
let g:StslineColorBlue   = "#89dceb"  " Catppuccin Cyan
let g:StslineColorViolet = "#cba6f7"  " Catppuccin Purple
let g:StslineColorYellow = "#f9e2af"  " Catppuccin Yellow
let g:StslineColorOrange = "#fab387"  " Catppuccin Orange

let g:StslineColorLight  = "#45475a"  " Catppuccin Light Background
let g:StslineColorLight1 = "#313244"  " Catppuccin Lighter Background
let g:StslineColorDark   = "#1e1e2e"  " Catppuccin Background
let g:StslineColorDark1  = "#181825"  " Catppuccin Dark Background
let g:StslineColorDark2  = "#11111b"  " Catppuccin Darker Background

" Define colors
let g:StslineBackColor   = g:StslineColorDark
let g:StslineOnBackColor = g:StslineColorLight1
let g:StslineOnPriColor  = g:StslineColorDark
let g:StslineSecColor    = g:StslineColorDark2
let g:StslineOnSecColor  = g:StslineColorLight1

" Create highlight groups
execute 'highlight StslineSecColorFG guifg=' . g:StslineSecColor   ' guibg=' . g:StslineBackColor
execute 'highlight StslineSecColorBG guifg=' . g:StslineColorLight ' guibg=' . g:StslineSecColor
execute 'highlight StslineBackColorBG guifg=' . g:StslineColorLight ' guibg=' . g:StslineBackColor
execute 'highlight StslineBackColorFGSecColorBG guifg=' . g:StslineBackColor ' guibg=' . g:StslineSecColor
execute 'highlight StslineSecColorFGBackColorBG guifg=' . g:StslineSecColor ' guibg=' . g:StslineBackColor
execute 'highlight StslineModColorFG guifg=' . g:StslineColorYellow ' guibg=' . g:StslineBackColor

" Enable statusline
set laststatus=2

" Disable showmode - i.e. Don't show mode like --INSERT-- in current statusline.
set noshowmode

" Disable the ruler
set noruler

" Enable GUI colors for terminals (Some terminals may not support this, so you'll have to *manually* set color pallet for tui colors. Lie tuibg=255, tuifg=120, etc.).
set termguicolors

" Understand statusline elements

" %{StslineMode()}  = Output of a function
" %#StslinePriColorBG# = Highlight group
" %F, %c, etc. are variables which contain value like - current file path, current colums, etc.
" %{&readonly?\"\ \":\"\"} = If file is readonly ? Then "Lock icon" Else : "Nothing"
" %{get(b:,'coc_git_status',b:GitBranch)}    = If b:coc_git_status efists, then it's value, else value of b:GitBranch
" &filetype, things starting with & are also like variables with info.
" \  - Is for escaping a space. \" is for escaping a double quote.
" %{&fenc!='utf-8'?\"\ \":''}   = If file encoding is NOT!= 'utf-8' ? THEN output a "Space" else : no character 

" Define active statusline

function! ActivateStatusline()
call GetFileType()
setlocal statusline=%#StslinePriColorBG#\ %{StslineMode()}%#StslineGitBranchColor#%{get(b:,'coc_git_status',b:GitBranch)}%{get(b:,'coc_git_blame','')}%#StslineBackColorFGPriColorBG#%#StslinePriColorFG#\ %{&readonly?\"\ \":\"\"}%F\ %#StslineModColorFG#%{&modified?\"\ \":\"\"}%=%#StslinePriColorFG#\ %{b:FiletypeIcon}%{&filetype}\ %#StslineSecColorFG#%#StslineSecColorBG#%{&fenc!='utf-8'?\"\ \":''}%{&fenc!='utf-8'?&fenc:''}%{&fenc!='utf-8'?\"\ \":''}%#StslinePriColorFGSecColorBG#%#StslinePriColorBG#\ %p\%%\ %#StslinePriColorBGBold#%l%#StslinePriColorBG#/%L\ :%c\ 
endfunction

" Define Inactive statusline

function! DeactivateStatusline()

if !exists("b:GitBranch") || b:GitBranch == ''
setlocal statusline=%#StslineSecColorBG#\ INACTIVE\ %#StslineSecColorBG#%{get(b:,'coc_git_statusline',b:GitBranch)}%{get(b:,'coc_git_blame','')}%#StslineBackColorFGSecColorBG#%#StslineBackColorBG#\ %{&readonly?\"\ \":\"\"}%F\ %#StslineModColorFG#%{&modified?\"\ \":\"\"}%=%#StslineBackColorBG#\ %{b:FiletypeIcon}%{&filetype}\ %#StslineSecColorFGBackColorBG#%#StslineSecColorBG#\ %p\%%\ %l/%L\ :%c\ 

else
setlocal statusline=%#StslineSecColorBG#%{get(b:,'coc_git_statusline',b:GitBranch)}%{get(b:,'coc_git_blame','')}%#StslineBackColorFGSecColorBG#%#StslineBackColorBG#\ %{&readonly?\"\ \":\"\"}%F\ %#StslineModColorFG#%{&modified?\"\ \":\"\"}%=%#StslineBackColorBG#\ %{b:FiletypeIcon}%{&filetype}\ %#StslineSecColorFGBackColorBG#%#StslineSecColorBG#\ %p\%%\ %l/%L\ :%c\ 
endif

endfunction

" Get Statusline mode & also set primary color for that mode
function! StslineMode()

    let l:CurrentMode=mode()

    if l:CurrentMode==#"n"
        let g:StslinePriColor     = g:StslineColorOrange
        let b:CurrentMode = "NORMAL "

    elseif l:CurrentMode==#"i"
        let g:StslinePriColor     = g:StslineColorViolet
        let b:CurrentMode = "INSERT "

    elseif l:CurrentMode==#"c"
        let g:StslinePriColor     = g:StslineColorYellow

        let b:CurrentMode = "COMMAND "

    elseif l:CurrentMode==#"v"
        let g:StslinePriColor     = g:StslineColorBlue
        let b:CurrentMode = "VISUAL "

    elseif l:CurrentMode==#"V"
        let g:StslinePriColor     = g:StslineColorBlue
        let b:CurrentMode = "V-LINE "

    elseif l:CurrentMode==#"\<C-v>"
        let g:StslinePriColor     = g:StslineColorBlue
        let b:CurrentMode = "V-BLOCK "

    elseif l:CurrentMode==#"R"
        let g:StslinePriColor     = g:StslineColorViolet
        let b:CurrentMode = "REPLACE "

    elseif l:CurrentMode==#"s"
        let g:StslinePriColor     = g:StslineColorBlue
        let b:CurrentMode = "SELECT "

    elseif l:CurrentMode==#"t"
        let g:StslinePriColor     =g:StslineColorYellow
        let b:CurrentMode = "TERM "

    elseif l:CurrentMode==#"!"
        let g:StslinePriColor     = g:StslineColorYellow
        let b:CurrentMode = "SHELL "

    endif

    call UpdateStslineColors()

    return b:CurrentMode

endfunction

" Update colors. Recreate highlight groups with new Primary color value.
function! UpdateStslineColors()

execute 'highlight StslinePriColorBG           guifg=' . g:StslineOnPriColor ' guibg=' . g:StslinePriColor
execute 'highlight StslinePriColorBGBold       guifg=' . g:StslineOnPriColor ' guibg=' . g:StslinePriColor ' gui=bold'
execute 'highlight StslinePriColorFG           guifg=' . g:StslinePriColor   ' guibg=' . g:StslineBackColor
execute 'highlight StslinePriColorFGSecColorBG guifg=' . g:StslinePriColor   ' guibg=' . g:StslineSecColor
execute 'highlight StslineSecColorFGPriColorBG guifg=' . g:StslineSecColor   ' guibg=' . g:StslinePriColor
execute 'highlight StslineGitBranchColor       guifg=' . g:StslinePriColor . ' guibg=' . g:StslineSecColor

if !exists("b:GitBranch") || b:GitBranch == ''
execute 'highlight StslineBackColorFGPriColorBG guifg=' . g:StslineBackColor ' guibg=' . g:StslinePriColor
endif

endfunction

" Get git branch name

function! GetGitBranch()
let b:GitBranch=""
try
    let l:dir=expand('%:p:h')
    let l:gitrevparse = system("git -C ".l:dir." rev-parse --abbrev-ref HEAD")
    if !v:shell_error
        let b:GitBranch="   ".substitute(l:gitrevparse, '\n', '', 'g')." "
        execute 'highlight StslineBackColorFGPriColorBG guifg=' . g:StslineBackColor ' guibg=' . g:StslineSecColor
    endif
catch
endtry
endfunction

" Get filetype & custom icon. Put your most used file types first for optimized performance.

function! GetFileType()

if &filetype == 'c'
let b:FiletypeIcon = ' '

elseif &filetype == 'python'
let b:FiletypeIcon = ' '

elseif &filetype == 'cpp'
let b:FiletypeIcon = ' '

elseif &filetype == 'kotlin'
let b:FiletypeIcon == ' '

elseif &filetype == 'javascript'
let b:FiletypeIcon = ' '

elseif &filetype == 'markdown'
let b:FiletypeIcon = ' '

elseif &filetype == 'typescript'
let b:FiletypeIcon = ' '

elseif &filetype == 'rust'
let b:FiletypeIcon = ' '

elseif &filetype == 'html'
let b:FiletypeIcon = ' '

elseif &filetype == 'scss'
let b:FiletypeIcon = ' '

elseif &filetype == 'css'
let b:FiletypeIcon = ' '

elseif &filetype == 'javascriptreact'
let b:FiletypeIcon = ' '

elseif &filetype == 'sh' || &filetype == 'zsh'
let b:FiletypeIcon = ' '

elseif &filetype == 'vim'
let b:FiletypeIcon = ' '

elseif &filetype == ''
let b:FiletypeIcon = ''

elseif &filetype == 'ruby'
let b:FiletypeIcon = ' '

elseif &filetype == 'go'
let b:FiletypeIcon = ' '

elseif &filetype == 'lua'
let b:FiletypeIcon = ' '

elseif &filetype == 'haskel'
let b:FiletypeIcon = ' '

else
let b:FiletypeIcon = ' '

endif
endfunction

" Get git branch name after entering a buffer
augroup GetGitBranch
    autocmd!
    autocmd BufEnter * call GetGitBranch()
augroup END

" Set active / inactive statusline after entering, leaving buffer
augroup SetStslineline
    autocmd!
    autocmd BufEnter,WinEnter * call ActivateStatusline()
    autocmd BufLeave,WinLeave * call DeactivateStatusline()
augroup END


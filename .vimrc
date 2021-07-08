set nocompatible

filetype plugin on
filetype indent on
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set autoindent
set smarttab

set relativenumber
set number

syntax on
set hlsearch
set ignorecase
set smartcase
set incsearch

" set mouse+=a
set shortmess+=I

set backspace=indent,eol,start
set laststatus=2

nnoremap <Left>  :echoe "Use h"<CR>
nnoremap <Right> :echoe "Use l"<CR>
nnoremap <Up>    :echoe "Use k"<CR>
nnoremap <Down>  :echoe "Use j"<CR>
" nnoremap <Esc>   :noh<CR>

nnoremap <C-j> <C-e>
nnoremap <C-k> <C-y>
noremap H ^
noremap L $


" local customizations in ~/.vimrc_local
" let $LOCALFILE=expand("~/.vimrc_local")
" if filereadable($LOCALFILE)
"     source $LOCALFILE
" endif

autocmd FileType python,sh set commentstring=#\ %s
autocmd FileType java,c,cpp set commentstring=//\ %s
autocmd FileType vim set commentstring=\"\ %s

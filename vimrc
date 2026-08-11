" EPITA PIE vimrc - zero plugins, works out of the box on vim-full 9.2 (NixOS PIE)
" Superset of vimrc.exam so exam muscle memory transfers 1:1.

" Any user vimrc suppresses defaults.vim; re-source it first (incsearch,
" scrolloff, mouse, ttimeout, filetype indent, last-cursor-position).
source $VIMRUNTIME/defaults.vim

" Interface
set number relativenumber
set mouse=a
set wildmode=longest:full,full wildoptions=pum
set laststatus=2 ruler showcmd
set scrolloff=8
set colorcolumn=80
set signcolumn=yes
set clipboard=unnamedplus
set encoding=utf-8
set ttimeoutlen=50
set hidden autoread
set splitright splitbelow

" Colors (habamax ships with vim 9, no plugin needed)
set termguicolors background=dark
silent! colorscheme habamax
syntax enable
filetype plugin indent on

" Indentation - EPITA C style: 4 spaces, no tabs
set expandtab tabstop=4 shiftwidth=4 softtabstop=4
set autoindent
autocmd FileType c,cpp setlocal cindent cinoptions=(0,:0
autocmd Filetype make setlocal noexpandtab

" EPITA style forbids trailing whitespace and tabs - make both visible
set list listchars=tab:>-,trail:-
highlight ExtraWhitespace ctermbg=red guibg=#802020
match ExtraWhitespace /\s\+$/

" Search (incsearch comes from defaults.vim)
set hlsearch ignorecase smartcase
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>

" Persistent undo, no clutter files
set undofile
if !isdirectory($HOME . '/.vim/undo')
  call mkdir($HOME . '/.vim/undo', 'p')
endif
set undodir=~/.vim/undo//
set nobackup nowritebackup noswapfile

" Movement
nnoremap <expr> j v:count ? 'j' : 'gj'
nnoremap <expr> k v:count ? 'k' : 'gk'
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz
nnoremap Q <nop>
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

nnoremap <Space> <Nop>
let mapleader=" "

" File explorer: netrw (built in), tree view
let g:netrw_banner = 0
let g:netrw_liststyle = 3
nnoremap <C-n> :Lexplore<CR>

" C workflow: make + quickfix
nnoremap <leader>m :make<CR>
nnoremap <leader>n :cnext<CR>
nnoremap <leader>p :cprev<CR>
nnoremap <leader>q :copen<CR>

" Format whole repo with EPITA clang-format wrapper (installed on the PIE)
if executable('clang-format-epita')
  command! Format !clang-format-epita
endif
" gq formats selection with clang-format using the repo's .clang-format
if executable('clang-format')
  autocmd FileType c,cpp setlocal formatprg=clang-format\ --style=file\ --fallback-style=none
endif

" Built-in power features, zero install (all exam-available):
packadd! termdebug      " :Termdebug ./a.out - GDB UI inside vim
packadd! comment        " gcc / gc to toggle comments
packadd! matchit        " % jumps on #if/#endif and more
runtime ftplugin/man.vim " :Man malloc - offline man pages
set path+=**            " :find name - fuzzy-ish file jumping, no plugin

" Rename word under cursor across the buffer
nnoremap <C-s> :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>

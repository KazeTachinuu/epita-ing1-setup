" EPITA PIE vimrc - zero plugins, works out of the box on vim-full 9.2 (NixOS PIE)
" Install: curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/config/master/.vimrc.pie -o ~/.vimrc

" Interface
set number relativenumber
set mouse=a
set wildmenu wildmode=longest:full,full
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

" EPITA style forbids trailing whitespace - make it visible
highlight ExtraWhitespace ctermbg=red guibg=#802020
match ExtraWhitespace /\s\+$/

" Search
set incsearch hlsearch ignorecase smartcase
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

" GDB inside vim (built in since vim 8.1): :Termdebug ./a.out
packadd! termdebug

" Rename word under cursor across the buffer
nnoremap <C-s> :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>

" ============================================================================
" EPITA PIE vimrc - vim-full 9.2, zero install, superset of vimrc.exam
" ============================================================================
" Layers: this file extends the 3-line exam core; muscle memory transfers.
" Every line changes verified behavior on the PIE image; defaults live in
" defaults.vim, the system vimrc, and ftplugins - not here.

" Any user vimrc suppresses defaults.vim (incsearch, scrolloff, mouse,
" ttimeout, filetype indent, last-cursor-position) - restore it first.
source $VIMRUNTIME/defaults.vim

" All autocmds live in one group, cleared on load: re-sourcing this file
" is idempotent (no duplicated handlers).
augroup pie | autocmd! | augroup END

" ---- interface -------------------------------------------------------------
set number relativenumber              " absolute + relative line numbers
set mouse=a                            " mouse in every mode, any terminal
set wildmode=longest:full,full         " complete longest, then cycle
set wildoptions=pum                    " popup completion menu for :commands
set laststatus=2                       " always show the statusline
set signcolumn=yes                     " stable gutter (LSP diagnostics)
set scrolloff=8                        " keep context around the cursor
set splitright splitbelow              " new splits open right/below
set hidden                             " switch buffers without saving first
set autoread                           " pick up external file changes
set ttimeoutlen=50                     " snappy Esc
set clipboard=unnamedplus              " y/p use the system clipboard

" ---- colors ----------------------------------------------------------------
set termguicolors background=dark
silent! colorscheme habamax            " also shipped: retrobox catppuccin sorbet

" ---- EPITA C style ---------------------------------------------------------
set colorcolumn=80                     " the style's hard line limit
set expandtab tabstop=4 shiftwidth=4 softtabstop=4
set shiftround                         " >> snaps to multiples of 4
set autoindent
set list listchars=tab:>-,trail:-      " expose tabs and trailing spaces
autocmd pie FileType c,cpp setlocal cinoptions=(0,:0 formatoptions+=j

" ---- search ----------------------------------------------------------------
set hlsearch ignorecase smartcase      " highlight all; smart casing
nnoremap <silent> <Esc><Esc> :nohlsearch<CR>

" ---- files: undo yes, clutter no -------------------------------------------
set undofile                           " undo history survives closing files
if !isdirectory($HOME . '/.vim/undo')
  call mkdir($HOME . '/.vim/undo', 'p')
endif
set undodir=~/.vim/undo//
set nowritebackup noswapfile           " no *~ and .swp litter in repos

" ---- movement --------------------------------------------------------------
nnoremap <expr> j v:count ? 'j' : 'gj'
nnoremap <expr> k v:count ? 'k' : 'gk'
nnoremap <C-d> <C-d>zz                 " half-page jumps keep cursor centered
nnoremap <C-u> <C-u>zz
vnoremap J :m '>+1<CR>gv=gv            " move selection down, reindent
vnoremap K :m '<-2<CR>gv=gv            " move selection up, reindent

" ---- leader ----------------------------------------------------------------
nnoremap <Space> <Nop>
let mapleader = " "

" ---- files and buffers -----------------------------------------------------
let g:netrw_banner = 0                 " netrw: no banner,
let g:netrw_liststyle = 3              "        tree view
nnoremap <C-n> :Lexplore<CR>
set path+=**                           " :find any file in the repo

" ---- C workflow: build, jump, format ---------------------------------------
set autowrite                          " save before :make
nnoremap <leader>m :make<CR>
nnoremap <leader>n :cnext<CR>
nnoremap <leader>p :cprev<CR>
nnoremap <leader>q :copen<CR>
nnoremap <leader>s :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>
if executable('clang-format-epita')
  command! Format !clang-format-epita  " format the whole repo (EPITA wrapper)
endif
if executable('clang-format')          " gq formats with the repo style
  autocmd pie FileType c,cpp setlocal formatprg=clang-format\ --style=file\ --fallback-style=none
endif

" ---- built-in power (all exam-available) -----------------------------------
packadd! termdebug                     " :Termdebug ./a.out - GDB UI in vim
packadd! comment                       " gcc / gc toggles comments
packadd! matchit                       " % jumps on #if / #endif
runtime ftplugin/man.vim               " :Man malloc (K also works bare)

" ---- LSP: clangd (preinstalled on the PIE) ---------------------------------
" install.sh clones yegappan/lsp into pack/kit/start once; inert without it.
autocmd pie User LspSetup call LspOptionsSet({'semanticHighlight': v:true})
autocmd pie User LspSetup call LspAddServer([{
    \ 'name': 'clangd', 'filetype': ['c', 'cpp'],
    \ 'path': 'clangd', 'args': ['--background-index'] }])
autocmd pie User LspAttached nnoremap <buffer> gd :LspGotoDefinition<CR>
autocmd pie User LspAttached nnoremap <buffer> gr :LspShowReferences<CR>
autocmd pie User LspAttached nnoremap <buffer> <leader>r :LspRename<CR>
autocmd pie User LspAttached nnoremap <buffer> K :LspHover<CR>

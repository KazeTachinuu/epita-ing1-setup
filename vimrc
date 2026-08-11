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
set number                             " line numbers (gcc and gdb speak in them)
set mouse=a                            " mouse in every mode, any terminal
set wildmode=longest:full,full         " complete longest, then cycle
set wildoptions=pum                    " popup completion menu for :commands
set laststatus=2                       " always show the statusline
set signcolumn=yes                     " stable gutter (LSP diagnostics)
set scrolloff=8                        " keep context around the cursor
set cursorline                         " highlight the current line
set breakindent                        " wrapped lines keep their indent
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
nnoremap <Down> gj
nnoremap <Up> gk
inoremap <Down> <C-o>gj
inoremap <Up> <C-o>gk
"" half-page jumps and search hits keep the cursor centered
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz
nnoremap n nzzzv
nnoremap N Nzzzv
" join lines without moving the cursor
nnoremap J mzJ`z

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
" :Format runs the EPITA wrapper over the whole repo
if executable('clang-format-epita')
  command! Format !clang-format-epita
endif
if executable('clang-format')          " gq formats with the repo style
  autocmd pie FileType c,cpp setlocal formatprg=clang-format\ --style=file\ --fallback-style=none
endif

" auto-format C files on save (vim-clang-format plugin, cloned by
" install.sh; inert without it). Only when a .clang-format governs the file.
let g:clang_format#auto_format = 1
let g:clang_format#detect_style_file = 1
let g:clang_format#enable_fallback_style = 0

" ---- built-in power (all exam-available) -----------------------------------
packadd! termdebug                     " :Termdebug ./a.out - GDB UI in vim
packadd! comment                       " gcc / gc toggles comments
packadd! matchit                       " % jumps on #if / #endif
runtime ftplugin/man.vim               " :Man malloc (K also works bare)

" ---- LSP: clangd (preinstalled on the PIE) ---------------------------------
" install.sh clones yegappan/lsp into pack/kit/start once; inert without it.
" Snippet support (function-argument placeholders) lights up when vsnip is
" present; Tab jumps between placeholders.
autocmd pie User LspSetup call LspOptionsSet(extend(
    \ {'semanticHighlight': v:true},
    \ exists(':VsnipOpen') == 2 ? {'snippetSupport': v:true, 'vsnipSupport': v:true} : {}))
autocmd pie VimEnter * if exists(':VsnipOpen') == 2
    \ | imap <expr> <Tab>   vsnip#jumpable(1)  ? '<Plug>(vsnip-jump-next)' : '<Tab>'
    \ | smap <expr> <Tab>   vsnip#jumpable(1)  ? '<Plug>(vsnip-jump-next)' : '<Tab>'
    \ | imap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
    \ | smap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
    \ | endif
autocmd pie User LspSetup call LspAddServer([{
    \ 'name': 'clangd', 'filetype': ['c', 'cpp'],
    \ 'path': 'clangd', 'args': ['--background-index', '--fallback-style=none'] }])
autocmd pie User LspAttached nnoremap <buffer> gd :LspGotoDefinition<CR>
autocmd pie User LspAttached nnoremap <buffer> gr :LspShowReferences<CR>
autocmd pie User LspAttached nnoremap <buffer> <leader>r :LspRename<CR>
autocmd pie User LspAttached nnoremap <buffer> K :LspHover<CR>

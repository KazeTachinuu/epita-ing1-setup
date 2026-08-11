# EPITA PIE starter kit

A minimal, tested dev environment for the C piscine, built from how the
PIE actually works (nixpie source): your local home is wiped every session,
but the PIE runs `~/afs/.confs/install.sh` at every login. This kit lives in
`~/afs/.confs/` and re-links itself each session, idempotently.

## Install (once, from any PIE machine or via the SSH gate)

```sh
curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/config/master/pie/setup.sh | sh
```

One line, everything: vim (LSP, auto-pairs, snippets, format-on-save),
bash, gdb, tmux, readline, dark alacritty, and a checksum-verified
starship prompt (`PIE_MINIMAL=1` skips it). Log out, log in: done, on
every PIE machine on every campus. Re-run any time to update.

## What you get

- `vimrc`: Vim 9 builtins first (`Ctrl+N` file tree, `Space+m` make +
  quickfix, `:Termdebug ./a.out` GDB UI, 80-column and tab/trailing
  guards for the 75%-malus style check) plus the four-plugin layer
  below: LSP with clangd, auto-pairs, snippets, format-on-save.
- `bashrc`: git-aware prompt with dirty state, `cc99` / `ccsan` compile
  aliases matching the moulinette's flags (-Werror, ASAN+UBSAN),
  `cctest` for criterion suites, readline upgrades via `inputrc`.
- `gdbinit`, `tmux.conf`, `alacritty.toml`: history, pretty-print,
  mouse, dark terminal.

## Exams

Exam images reset everything: no AFS, no network, no installing. Bare vim
loads its built-in `defaults.vim` (incsearch, scrolloff, mouse, filetype
indent), but writing any `~/.vimrc` silently disables that, which is why
line 1 exists. Memorize exactly 3 lines (`vimrc.exam`), order only
matters for line 1:

```vim
source $VIMRUNTIME/defaults.vim
set nu et sw=4 sts=4 cc=80
set hls ic scs cb=unnamedplus
```

No Makefile guard is needed: line 1 re-enables filetype plugins, and
vim's built-in make ftplugin already forces real tabs in Makefiles
(verified in the image). Every removed line is one less thing to
misremember under stress.

Habits beat config on an offline exam - all built in, know them cold:
`K` on a word opens its man page (your only documentation), `Ctrl-N`
completes your own identifiers in insert mode, `:make` then `:cn` jumps
error to error, `:term` opens a shell in a split, `*` highlights every
use of the word under the cursor, `Ctrl-W s/v/w` manages splits, and
criterion compiles with plain `gcc t.c -lcriterion -o t`. Optional
comfort (undofile, packadd comment/termdebug) is listed commented-out in
vimrc.exam.

Rehearse in the harness until the 3 lines are reflex: `./harness.sh exam`.

## The rituals worth drilling

- Compile: `gcc -std=c99 -Wall -Wextra -Werror -pedantic -g3 -fsanitize=address,undefined`
  (the moulinette builds with -Werror and grades ASAN; UBSAN is free)
- Criterion tests: `gcc t.c -lcriterion -o t && ./t` - no other flags needed
- Style gate before every push: `clang-format --Werror --dry-run *.c`
  (works only with the `.clang-format` at the repo root)
- Submit: `git push --follow-tags` - the forgotten tag is the classic zero

## The plugin layer: four plugins, no manager

install.sh clones a curated set once into
`afs/.confs/vim/pack/kit/start/` (vim's native package system, no
Vundle/vim-plug needed) and links `~/.vim` there, so they exist on
every machine forever after:

- [yegappan/lsp](https://github.com/yegappan/lsp) + the preinstalled
  clangd: `gd` goto-definition, `gr` references, `K` hover docs,
  `Space r` rename, live diagnostics, semantic highlighting, and
  completion with argument snippets (Tab jumps placeholders)
- [LunarWatcher/auto-pairs](https://github.com/LunarWatcher/auto-pairs):
  brackets and quotes close themselves
- [hrsh7th/vim-vsnip](https://github.com/hrsh7th/vim-vsnip): the snippet
  engine behind LSP completions
- [rhysd/vim-clang-format](https://github.com/rhysd/vim-clang-format):
  C files auto-format on save, only when a `.clang-format` governs them
  (the graded style applies itself)

Update (rarely needed):
`for d in ~/afs/.confs/vim/pack/kit/start/*/; do git -C "$d" pull; done`

Any plugin or colorscheme installs the same way - clone and it exists on
every machine (verified with sonokai):

```sh
git clone --depth 1 https://github.com/sainnhe/sonokai \
    ~/afs/.confs/vim/pack/kit/start/sonokai
```

then point the `colorscheme` line in vimrc at it. Vim 9 already ships
habamax, retrobox, catppuccin and sorbet if you just want a different
built-in look.
Exams have no AFS, so none of this exists there - which is why the
mappings live behind `LspAttached` and the exam config never mentions it.

## Optional extras (one download, persist on AFS, absent in exams)

The bashrc has inert hooks for these; installing is just putting the
files on AFS (both verified running on the PIE image):

```sh
# starship prompt (static binary, works everywhere):
mkdir -p ~/afs/.confs/bin
curl -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C ~/afs/.confs/bin

# ble.sh: fish-style autosuggestions + syntax highlighting for bash.
# Caveat before you run this: only the nightly build supports bash 5.3,
# and nightly is a moving target with no checksum to pin - you are
# trusting upstream at fetch time. Inspect it if that bothers you.
curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
    | tar xJ -C ~/afs/.confs && mv ~/afs/.confs/ble-nightly ~/afs/.confs/blesh
```

```sh
# GEF: power-user gdb (heap, registers, context panel), pinned + verified.
# Learn plain gdb first; this is for when you outgrow it.
curl -fsSL https://raw.githubusercontent.com/hugsy/gef/2026.01/gef.py -o ~/afs/.confs/gef.py
echo "04cdfe961f1e9151933d32cf6b548d9e6a76a1aef8b27c020c575b8d4264ed20  $HOME/afs/.confs/gef.py" | sha256sum -c - || rm ~/afs/.confs/gef.py
```

The kit's core deliberately excludes them: exams have no AFS, and the
core must match what your hands know there.

## Developing the kit (maintainers)

Requires docker, bats, and a local `nixos-pie` image (build once from the
[epita/nixpie](https://github.com/epita/nixpie) flake:
`nix build github:epita/nixpie#nixos-pie-docker` then `docker load`).

```sh
./harness.sh login      # simulated PIE login with the kit applied
./harness.sh exam       # stock exam machine, nothing applied
./harness.sh gui        # full i3 session in a resizable window
./harness.sh vm         # boot the REAL PIE in QEMU/KVM (top fidelity)
./harness.sh reset      # wipe the fake AFS -> factory default
bats test.bats          # 6 tests: the kit applies and can never break a login
```

The harness replicates the real login path from nixpie's PAM hook, including
the gotchas: `install.sh` must be executable or the PIE silently skips it.

## zsh / neovim?

Neither exists on the PIE, and exams give you bash + vim only. Build your
muscle memory on what is guaranteed everywhere. On regular (non-exam) PIE
sessions the Nix store is writable, so if you really want them:
`nix profile install nixpkgs#neovim` (re-fetched each boot, cached, fast),
then `exec zsh` from bash. Not recommended during the piscine.

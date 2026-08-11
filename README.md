# EPITA PIE starter kit

A minimal, plugin-free dev environment for the C piscine, built from how the
PIE actually works (nixpie source): your local home is wiped every session,
but the PIE runs `~/afs/.confs/install.sh` at every login. This kit lives in
`~/afs/.confs/` and re-links itself each session, idempotently.

## Install (once, from any PIE machine or via the SSH gate)

```sh
mkdir -p ~/afs/.confs && cd ~/afs/.confs
base=https://raw.githubusercontent.com/KazeTachinuu/config/master/pie
for f in install.sh vimrc bashrc; do curl -fsSL "$base/$f" -o "$f"; done
chmod +x install.sh && ./install.sh
```

Log out, log in: done. Works on every PIE machine on every campus.

## What you get

- `vimrc`: Vim 9 builtins only, nothing to install, nothing to break.
  `Ctrl+N` file tree, `Space+m` make + quickfix (`Space+n`/`p`/`q`),
  `:Format` runs `clang-format-epita` on the whole repo, `gq` formats a
  selection, `:Termdebug ./a.out` is a full GDB UI, 80-column marker and
  trailing-whitespace highlight because the moulinette's style check has a
  75% malus.
- `bashrc`: git-aware prompt, `cc99` / `ccsan` compile aliases matching the
  moulinette's flags (it builds with -Werror and grades ASAN), `cctest` for
  criterion suites.

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

## The plugin layer: one plugin, no manager

Day-to-day vim gains real IDE features from a single plugin:
[yegappan/lsp](https://github.com/yegappan/lsp) talking to the clangd
already installed on the PIE. install.sh clones it once into
`afs/.confs/vim/pack/kit/start/` (vim's native package system, no
Vundle/vim-plug needed) and links `~/.vim` there, so it works on every
machine forever after. In C files: `gd` goto-definition, `gr` references,
`K` hover docs, `Space r` rename, live diagnostics as you type.
Update it (rarely needed): `git -C ~/afs/.confs/vim/pack/kit/start/lsp pull`.

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

# ble.sh: fish-style autosuggestions + syntax highlighting for bash:
curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
    | tar xJ -C ~/afs/.confs && mv ~/afs/.confs/ble-nightly ~/afs/.confs/blesh
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
./harness.sh gui        # full i3 session in a Xephyr window
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

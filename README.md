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

# EPITA PIE starter kit

Your PIE home is wiped every session, but the PIE runs
`~/afs/.confs/install.sh` at every login. This kit lives there and
re-links itself each session, idempotently.

## Install (once, from any PIE machine or the SSH gate)

```sh
curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/config/master/pie/setup.sh | sh
```

Log out, log in: done, on every PIE machine on every campus. Re-run any
time to update. `PIE_MINIMAL=1` skips the starship prompt.

## What you get

- `vimrc`: Vim 9 builtins (`Ctrl+N` file tree, `Space+m` make + quickfix,
  `:Termdebug`, 80-column and tab/trailing guards) plus four plugins via
  vim's native package system: [yegappan/lsp](https://github.com/yegappan/lsp)
  with clangd (`gd`, `gr`, `K`, `Space r` rename, diagnostics, completion),
  [auto-pairs](https://github.com/LunarWatcher/auto-pairs),
  [vim-vsnip](https://github.com/hrsh7th/vim-vsnip),
  [vim-clang-format](https://github.com/rhysd/vim-clang-format)
  (format-on-save when a `.clang-format` governs the file).
- `bashrc`: git-aware prompt, `cc99` / `ccsan` aliases matching the
  moulinette's flags (-Werror, ASAN+UBSAN), `cctest` for criterion.
- `gdbinit`, `tmux.conf`, `alacritty.toml`, `inputrc`.

Any extra plugin installs the same way: clone into
`~/afs/.confs/vim/pack/kit/start/` and it exists on every machine.
Update: `for d in ~/afs/.confs/vim/pack/kit/start/*/; do git -C "$d" pull; done`

## Exams

Exam images reset everything: no AFS, no network. Memorize exactly 3
lines (`vimrc.exam`); line 1 must come first, it re-enables the
`defaults.vim` that writing any `~/.vimrc` silently disables:

```vim
source $VIMRUNTIME/defaults.vim
set nu et sw=4 sts=4 cc=80
set hls ic scs cb=unnamedplus
```

Habits beat config offline: `K` opens the man page, `Ctrl-N` completes
identifiers, `:make` then `:cn` jumps errors, `:term` opens a shell,
`*` highlights the word under the cursor, `Ctrl-W s/v/w` manages splits,
criterion compiles with plain `gcc t.c -lcriterion -o t`.
Rehearse until the 3 lines are reflex: `./harness.sh exam`.

## Rituals worth drilling

- Compile: `gcc -std=c99 -Wall -Wextra -Werror -pedantic -g3 -fsanitize=address,undefined`
- Style gate before every push: `clang-format --Werror --dry-run *.c`
- Submit: `git push --follow-tags` (the forgotten tag is the classic zero)

## Optional extras (persist on AFS, absent in exams)

```sh
# starship prompt (also installed by setup.sh unless PIE_MINIMAL=1):
mkdir -p ~/afs/.confs/bin
curl -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C ~/afs/.confs/bin

# ble.sh autosuggestions (nightly only supports bash 5.3; unpinned, trust at fetch time):
curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
    | tar xJ -C ~/afs/.confs && mv ~/afs/.confs/ble-nightly ~/afs/.confs/blesh

# GEF: power-user gdb, pinned + verified. Learn plain gdb first.
curl -fsSL https://raw.githubusercontent.com/hugsy/gef/2026.01/gef.py -o ~/afs/.confs/gef.py
echo "04cdfe961f1e9151933d32cf6b548d9e6a76a1aef8b27c020c575b8d4264ed20  $HOME/afs/.confs/gef.py" | sha256sum -c - || rm ~/afs/.confs/gef.py
```

## Developing the kit

Requires docker, bats, and a local `nixos-pie` image (build once:
`nix build github:epita/nixpie#nixos-pie-docker` then `docker load`).

```sh
./harness.sh login      # simulated PIE login with the kit applied
./harness.sh exam       # stock exam machine, nothing applied
./harness.sh gui        # full i3 session in a window
./harness.sh vm         # boot the real PIE in QEMU/KVM
./harness.sh reset      # wipe the fake AFS
bats test.bats
```

zsh / neovim: neither exists on the PIE and exams give you bash + vim
only. Build muscle memory on what is guaranteed everywhere.

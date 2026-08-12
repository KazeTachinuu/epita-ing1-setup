# epita-ing1-setup

Dev environment for the EPITA PIE. The PIE wipes your home every session
but runs `~/afs/.confs/install.sh` at each login; this kit lives there
and re-links itself, so it follows you to every machine on every campus.

```sh
curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/master/setup.sh | sh
```

Log out, log back in. Re-run any time to update.

![the kit cheatsheet on the PIE](docs/pie.png)

- **vim**: clangd LSP (definition, references, rename, inline
  diagnostics, code actions), auto-pairs, snippets (`main<Tab>`),
  format-on-save with the moulinette's `.clang-format`
- **bash**: git-aware prompt, `cc99` / `ccsan` with the moulinette's
  flags (-Werror, ASAN+UBSAN), `cctest` / `cccov` for criterion,
  `submit <tag>` (clean-tree + format gate, annotated tag, push)
- **style**: `coding-style-check`, a 54-rule
  [linter](https://github.com/KazeTachinuu/epita-coding-style) for what
  clang-format cannot check
- **gdb**: history, pretty-print, GEF
- **search**: fzf (fuzzy `Ctrl-R` history, `Ctrl-T` files), fd, ripgrep,
  readline prefix history search on the arrows
- **tmux**, **alacritty**, **starship** with my prompt config
- **`kit`**: one-screen cheatsheet of all of the above

Configs are fetched from a pinned commit; binaries (starship, fzf, fd,
rg, GEF) are checksum-verified. `PIE_MINIMAL=1` skips the downloads.

## Exams

Exam machines have no AFS and no network; nothing above exists there.
Memorize 3 lines (`vimrc.exam`), line 1 first: writing any `~/.vimrc`
disables the built-in `defaults.vim`, and line 1 turns it back on.

```vim
source $VIMRUNTIME/defaults.vim
set nu et sw=4 sts=4 cc=80
set hls ic scs cb=unnamedplus
```


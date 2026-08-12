# EPITA PIE starter kit

```sh
curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/config/master/pie/setup.sh | sh
```

Log out, log in: done, on every PIE machine on every campus, forever.
Re-run any time to update.

You get vim (clangd LSP, auto-pairs, snippets, format-on-save), bash
(`cc99` / `ccsan` moulinette-flag aliases, `cctest`, git prompt), gdb,
tmux, readline and a starship prompt (`PIE_MINIMAL=1` skips it). It
survives the session wipe because the PIE runs `~/afs/.confs/install.sh`
at every login.

## Exams

No AFS, no network, nothing installed. Memorize 3 lines, line 1 first:

```vim
source $VIMRUNTIME/defaults.vim
set nu et sw=4 sts=4 cc=80
set hls ic scs cb=unnamedplus
```

Practice on the real image: `./harness.sh exam`

## Hacking on the kit

Needs docker, bats, and the nixos-pie image
(`nix build github:epita/nixpie#nixos-pie-docker`, then `docker load`).

```sh
./harness.sh login   # simulated PIE login, kit applied
./harness.sh exam    # stock exam machine
./harness.sh gui     # full i3 session in a window
./harness.sh vm      # boot the real PIE in QEMU/KVM
bats test.bats
```

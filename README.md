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

## From your own machine

`kinit <login>@CRI.EPITA.FR`, then ssh and AFS work passwordless with:

```
# ~/.ssh/config
Host ssh.cri.epita.fr
    User <login>
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes
```

```sh
sshfs -o reconnect ssh.cri.epita.fr:/afs/cri.epita.fr/user/<l>/<ll>/<login>/u ~/pie-afs
```

## Exams

Exam machines have no AFS and no network; nothing above exists there.
Memorize 3 lines (`vimrc.exam`), line 1 first: writing any `~/.vimrc`
disables the built-in `defaults.vim`, and line 1 turns it back on.

```vim
source $VIMRUNTIME/defaults.vim
set nu et sw=4 sts=4 cc=80
set hls ic scs cb=unnamedplus
```

Practice on the real image: `./harness.sh exam`

## Development

Needs docker, bats, and the nixos-pie image:
`nix build github:epita/nixpie#nixos-pie-docker`, then `docker load`.

| command | what it does |
|---|---|
| `./harness.sh login` | PIE shell, kit applied |
| `./harness.sh exam` | stock exam machine |
| `./harness.sh gui` | full i3 desktop in a window |
| `./harness.sh vm` | boot the real PIE in a window; close it to shut down |
| `./harness.sh paste` | type the host clipboard into the running VM |
| `./harness.sh reset` | wipe the fake AFS |
| `./harness.sh vmreset` | wipe the VM disk, keep the VM image |
| `bats test.bats` | the kit applies, and can never break a login |

The harness replays the real login path from nixpie's PAM hook.

Clipboard and the VM: host to VM needs nothing (`paste`). VM to host
(yank out of the VM) additionally needs the guest agent:
`nix profile install nixpkgs#spice-vdagent`, then as root
`spice-vdagentd` and `spice-vdagent`.


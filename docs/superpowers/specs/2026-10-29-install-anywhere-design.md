# Install anywhere: design

Status: draft for review (2026-10-29)

## Intent

The kit started as a PIE environment: configs on AFS, re-linked at each
login by PAM. Its owner wants the same environment everywhere: vim with
LSP and snippets, the bash setup and helpers (`cc99`, `submit`, `kit`...),
the starship prompt, tmux, gdb with GEF, and the tools (tldr, fzf, rg, fd,
bat, coding-style-check, ignore). One command on any Linux machine, real,
VM or container, with or without root, should give that environment. And
one command must take it all back out cleanly.

## Goals

- One-line install, as today (`curl -fsSL .../setup.sh | sh`), that
  detects where it runs and does the right thing.
- Same kit everywhere: same configs, same helpers, EPITA ones included.
- Supported: Debian, Ubuntu, Arch and their derivatives; x86_64 and
  aarch64 (a Debian container on an Apple Silicon Mac is aarch64).
- Without root: everything that lives in `$HOME` (configs, plugins,
  pinned binaries), and a clear list of what is missing from the system.
- With root (or `sudo`): also the system packages the kit relies on.
- **Clean revert** (the owner calls it very important): `kit uninstall`
  removes exactly what the kit added and restores what it replaced,
  including the system packages it installed itself, never those that
  were already there.

## Non-goals

- macOS, Windows, BSD (WSL counts as Linux if it works, not a target).
- Distros other than the Debian and Arch families (Fedora etc.): the
  home part may work there; packages are not handled.
- Managing the user's own dotfiles beyond what the kit links.

## Anti-goals (failure even if it works)

- Losing or overwriting anything of the user's. Every replaced file is
  kept, and uninstall puts it back.
- Removing a system package the user had before the kit.
- Any change to PIE behavior. The PIE campus and PIE sshfs paths stay as
  they are now and keep passing `tests/` (46 + 13 + 31 checks).
- A login or shell start that waits on the network or fails because of
  the kit.
- Unpinned or unverified code: binaries stay pinned and checksum-verified
  per architecture; plugins stay pinned to commits.

## Environments (detection)

| Mode | How it is recognized | Kit home | Re-applied |
|------|----------------------|----------|------------|
| PIE campus | `~/afs` (AFS_DIR) is a symlink into `/afs/` (made by PAM) | `$AFS/.confs` | by PAM at each login (unchanged) |
| PIE from home | `$AFS/.confs` is on `fuse.sshfs` | `$AFS/.confs`, extras in `~/.pie` | unchanged |
| AFS layout, no PIE | `AFS_DIR` set explicitly, or `$AFS/.confs/.kit` already exists (an install of the current shape, e.g. a from-home user whose sshfs mount is down) | `$AFS/.confs` | as today |
| Standalone | anything else | `${XDG_DATA_HOME:-~/.local/share}/epita-kit` | once; links are permanent |

Rules are checked top to bottom. The "AFS layout, no PIE" row (designer's
call) keeps today's behavior wherever a user already has an AFS-shaped
kit or asks for one: a from-home user whose mount is down is never
silently reinstalled as standalone over their PIE setup, and the existing
`tests/` suites (which use an explicit `AFS_DIR` and the local-`~/afs`
fallback) keep passing unchanged. Only a machine with neither gets the
standalone layout; there, setup no longer creates a fake `~/afs`.

## Standalone mode

- Configs, plugins, binaries and GEF go under the kit home. The links
  into `$HOME` are the kit's links (vimrc, bashrc, gdbinit, inputrc,
  clang-format, ~/.vim, tmux/alacritty/starship under ~/.config). The CRI
  superset (mozilla, ssh, config...) is PIE-only and is never linked here.
- **bashrc:** standalone users have their own `~/.bashrc` (distro default
  or theirs). Designer's call: the kit does not replace it. It appends
  one marked source line
  (`# epita-kit` ... `. <kit>/bashrc`) and uninstall removes exactly that
  line. On the PIE, the link stays as now.
- Everything is installed by one run; `kit update` re-runs setup.sh.
- The `kit` function and the extras' PATH find the kit home from one
  variable set by the sourced bashrc, not from `~/afs`.

## System packages (root or sudo)

- Who decides (designer's call): `KIT_PACKAGES=yes|no` forces it.
  Otherwise: run as root (a Dockerfile `RUN`, a container) installs
  without asking; a user with `sudo` and a terminal gets one y/N prompt
  listing the packages, then sudo's own password prompt; no terminal and
  not root, or no sudo: skip and print the list and the command to run.
- `curl ... | sudo sh`: packages go system-wide, the home part goes to the
  invoking user (`SUDO_USER`), owned by them; plain root with no
  `SUDO_USER` (a container) uses root's home.
- Package sets (exact names per distro left to the builder): C toolchain
  (gcc, make), clangd, clang-format, gdb, valgrind, criterion, lcov, vim
  9 (with the features the vimrc uses), git, curl, python3 (+ pip for
  coding-style-check), tmux, xsel. Debian/Ubuntu via apt, Arch via pacman.
- Before installing, snapshot the installed package names; after, the
  journal records every package that is new (the named ones and the
  dependencies they pulled in). Only those are removed by uninstall, and
  only if nothing outside that set depends on them by then; anything
  still needed is kept and reported (designer's call).
- "Identical package list" means the same set of package names. The
  package manager may upgrade shared packages the user already had while
  installing; those versions are not rolled back.
- Arch: the kit never runs a full system upgrade (`-Syu`) on its own. It
  installs with `pacman -S --needed`; if that fails on a stale package
  database, it stops the package step and tells the user to run
  `pacman -Syu` themselves (designer's call: a system upgrade is not
  revertible, so it stays the user's decision).
- A distro whose vim is older than 9 (e.g. Ubuntu 22.04) gets a clear
  warning that LSP and snippets are off; the rest still works.

## Architectures

Each pinned binary gets a URL and a sha256 per architecture (x86_64,
aarch64). A tool with no upstream build for the machine is skipped with
a message, like a failed download today. The builder checks which
upstream releases exist for aarch64.

## The journal and `kit uninstall`

- The journal lives in the kit home and records, in order, each thing the
  kit did: link created (and what it replaced and where that went), file
  or dir created, line appended to a file, package installed.
- `kit uninstall` walks it backwards: removes links only if they still
  point where the kit put them, restores the moved-aside originals,
  removes appended lines, removes the packages it installed (asking for
  sudo the same way), then removes the kit home.
- Anything changed by the user since (a link repointed, a file edited) is
  left in place and reported, not forced.
- Uninstall works offline and does not need the network or a matching
  kit version: the journal plus the uninstall code shipped in the kit
  home are enough.
- On the PIE (and the AFS layout), the kit's files in `.confs` are a
  fixed, known set (the shipped configs, `.kit`, `bin/`, `pylib/`,
  `gef.py`, `fzf-key-bindings.bash`, `vim/pack/kit/`, and `~/.pie` on
  sshfs), so uninstall works for installs made before journals existed.
  It removes that set, then restores the user's previous files from
  `.confs.backup`. A kit file with no backup (the user had none) is
  removed, not replaced by a CRI default: the result is what they had
  before. User files in `.confs` that the kit never shipped (mozilla,
  ssh, config...) are never touched.
- Done means: after install then uninstall, `$HOME` is identical to
  before (same files, contents and link targets), and the package list is
  identical to before.
- Files the tools create while being used (`~/.gdb_history`,
  `~/.bash_history`, `~/.viminfo`, vim undo files, tldr and starship
  caches) are the user's data: uninstall never deletes them, and the
  done check ignores them (designer's call).

## Testing

Extend `tests/` (docker): debian:bookworm, ubuntu (24.04 and 22.04 for
the old-vim warning), archlinux; each as root and as a plain user; amd64
and arm64 (native on the owner's Mac). For each: install, check the
environment works (the same kinds of checks as `t-setup.sh`), uninstall,
diff `$HOME` and the package list against the snapshot from before. The
three PIE suites must keep passing unchanged.

## Left to the builder

Exact package names per distro; journal file format; how the uninstall
code is shipped (a script in the kit home vs the bashrc function);
aarch64 URLs and checksums; how existing old-shape standalone installs
are migrated; command names beyond `kit uninstall`.

# Install Anywhere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The same kit on any Debian/Ubuntu/Arch machine (x86_64 or
aarch64, root or not), installed by the existing one-liner and removed
cleanly by `kit uninstall`, with PIE behavior unchanged.

**Architecture:** `setup.sh` detects one of four modes (pie, sshfs, afs,
standalone) and picks the kit home. `install.sh` keeps doing the linking
and, in standalone, appends a marked line to `~/.bashrc` instead of
linking it; every change it makes outside the kit home is recorded in a
journal when one is active. A new `packages.sh` installs the system
packages (apt or pacman) and journals the new ones. A new `uninstall.sh`,
shipped in the kit home, replays the journal backwards (or, on AFS
layouts, removes the fixed set of kit files and restores
`.confs.backup`).

**Tech Stack:** POSIX sh (dash, bash, busybox ash), bash for `bashrc`,
docker for tests.

**Spec:** `docs/superpowers/specs/2026-10-29-install-anywhere-design.md`

## Global Constraints

- `setup.sh`, `install.sh`, `packages.sh`, `uninstall.sh`: POSIX sh; must
  pass under dash, bash and busybox ash (`tests/run.sh` with `SH=`).
- Code style as in the repo: 80 columns, 4-space indent, a comment says
  why above each non-obvious block, no trailing comments in gdbinit or
  inputrc.
- Binaries stay pinned and sha256-verified, now per architecture
  (x86_64, aarch64); plugins stay pinned to commits.
- A shell start never waits on the network; `install.sh` never fails a
  login (exit 0).
- PIE campus and PIE sshfs behavior unchanged: `tests/t-install.sh`,
  `tests/t-sshfs.sh`, `tests/t-setup.sh` pass unmodified, except for new
  checks appended to them.
- Never delete or overwrite a user's file; never remove a package the
  user had before the kit; never run `pacman -Syu`.
- Runtime files (`~/.bash_history`, `~/.gdb_history`, `~/.viminfo`,
  `~/.vim/undo/`, tldr and starship caches) are never deleted by
  uninstall.
- Each task ends with the full existing suite green:
  `tests/run.sh` (and the new suite once it exists).

## Review Focus

- A user's own `~/.bashrc` edited after install (lines added above and
  below the kit line): uninstall removes only the kit's marked line and
  leaves every other byte. Test in Task 3.
- `setup.sh` run twice in standalone, then uninstall: the original
  `~/.vimrc` comes back, not a kit file or a second backup. Test in
  Task 3.
- `kit uninstall` run a second time, or with no journal: does nothing,
  says so, exits 0. Test in Task 3.
- `curl | sh` as a sudo user: stdin is the script, so the y/N prompt must
  read `/dev/tty`; with no tty it skips and prints the command. Test in
  Task 5.
- A package the user already had (e.g. `gdb` preinstalled) survives
  uninstall even though the kit "wanted" it. Test in Task 6.

---

## File Structure

| File | Change | Responsibility |
|------|--------|----------------|
| `setup.sh` | modify | mode detection, kit home, per-arch binaries, calls packages.sh, sudo handoff |
| `install.sh` | modify | links; standalone bashrc line; journaling |
| `packages.sh` | create | package manager detection, package sets, policy, install, journal |
| `uninstall.sh` | create | journal replay, AFS fixed-set removal, package removal |
| `bashrc` | modify | kit home from `KIT_DIR`; `kit uninstall` |
| `gdbinit` | modify | GEF from `KIT_DIR` first |
| `tests/t-standalone.sh` | create | install / use / uninstall / diff on plain distro images |
| `tests/run.sh` | modify | distro images, `ARCH=`, the new suite |
| `tests/t-install.sh` | modify | append PIE uninstall check (T12) |
| `README.md`, `cheatsheet` | modify | document standalone install and `kit uninstall` |

Shared names (used across tasks, defined once here):

- `KIT_DIR`: absolute kit home. PIE/sshfs/afs: `$AFS/.confs`;
  standalone: `${XDG_DATA_HOME:-$HOME/.local/share}/epita-kit`. Exported
  by the bashrc line in standalone; derived from `AFS_DIR` elsewhere.
- `KIT_MODE`: `pie` | `sshfs` | `afs` | `standalone`, passed by setup.sh
  to install.sh and packages.sh in the environment. install.sh defaults
  to `pie` when unset (PAM does not set it).
- `KIT_JOURNAL`: path of the journal, `$KIT_DIR/.journal`. Set only in
  standalone. install.sh and packages.sh append to it only when it is
  set; PIE logins never write one.
- Journal line format, one action per line, fields separated by a TAB:
  `link<TAB><dst><TAB><src><TAB><backup or empty>`
  `line<TAB><file><TAB><exact line>`
  `pkg<TAB><apt|pacman><TAB><name>`
- The standalone `~/.bashrc` line, exactly (one line, `<KIT_DIR>`
  expanded at install time):
  `[ -r '<KIT_DIR>/bashrc' ] && KIT_DIR='<KIT_DIR>' && . '<KIT_DIR>/bashrc' # epita-kit`
- The AFS fixed set (Task 3): the files in setup.sh `FILES` plus
  `packages.sh uninstall.sh .kit bin pylib gef.py fzf-key-bindings.bash
  vim/pack/kit`, and `~/.pie` in sshfs mode.

### Task 1: Modes and the standalone layout

**Files:**
- Modify: `setup.sh` (top-level variables; `main` from the AFS fallback
  down to `cd "$EXTRAS"`)
- Modify: `install.sh` (`link bashrc`)
- Modify: `bashrc` (`_kitd`, `kit()`), `gdbinit` (GEF path list)
- Create: `tests/t-standalone.sh`
- Modify: `tests/run.sh` (suite list, `IMAGE=`)

**Interfaces:**
- Produces: `detect_mode` (setup.sh) prints one of `pie sshfs afs
  standalone`; `KIT_DIR`, `KIT_MODE` as defined above; `tests/run.sh`
  accepts `IMAGE=debian:bookworm|ubuntu:24.04|ubuntu:22.04|archlinux`
  for `t-standalone.sh` (default `debian:bookworm`).

- [ ] **Step 1: Write `tests/t-standalone.sh`** (runs as root in a plain
  distro container; installs `curl ca-certificates python3 git sudo` with
  the distro's manager first, creates user `student`, serves `/kit` on
  :8000 as `t-setup.sh` does, then runs the checks as `student` with
  `PIE_BASE=http://localhost:8000 KIT_PACKAGES=no`). Checks, same
  `chk` style as the other suites:
  - `setup.sh` exits 0
  - `~/afs` does not exist
  - `$HOME/.local/share/epita-kit/vimrc` exists and `~/.vimrc` links to it
  - `~/.bashrc` is still a regular file and its last line is the exact
    bashrc line above
  - `bash -ic 'echo $KIT_DIR; command -v rg; kit | head -1'` prints the
    kit home, `<kit home>/bin/rg`, and `EPITA PIE kit`
  - a pre-existing `~/.vimrc` containing `mine` is at
    `~/.vimrc.local-backup`

- [ ] **Step 2: Run it, expect FAIL** (`IMAGE=debian:bookworm
  tests/run.sh t-standalone.sh`: `~/afs` exists, no `.local/share`).

- [ ] **Step 3: Implement.**
  - `detect_mode` in setup.sh, rules in this order: `readlink "$AFS"`
    starts with `/afs/` → pie; `$AFS/.confs` exists on `fuse.sshfs` →
    sshfs; `AFS_DIR` set in the environment, or `$AFS/.confs/.kit`
    exists → afs; else standalone.
  - The dangling-`~/afs` → local dir conversion runs only in `afs` mode.
  - standalone: `KIT_DIR`/`DOT` and `EXTRAS` are the kit home; the
    first-run `.confs.backup` logic is not used (link backups cover it).
  - setup.sh runs `KIT_MODE=$mode AFS_DIR=... ./install.sh`; install.sh
    takes `DOT` from `KIT_DIR` when set, else `${AFS_DIR:-$HOME/afs}/.confs`.
  - install.sh, standalone: instead of `link bashrc`, append the bashrc
    line to `~/.bashrc` unless a line ending in `# epita-kit` is already
    there (create `~/.bashrc` if missing).
  - bashrc: `_kitd="${KIT_DIR:-${AFS_DIR:-$HOME/afs}/.confs}"`; `kit()`
    uses the same expression. gdbinit: try `$KIT_DIR/gef.py` before the
    current two paths.

- [ ] **Step 4: Run the new suite and the three PIE suites, expect
  PASS** (`tests/run.sh` then `IMAGE=debian:bookworm tests/run.sh
  t-standalone.sh`).

- [ ] **Step 5: Commit** — `Standalone mode: install outside AFS into
  ~/.local/share/epita-kit`.

### Task 2: The journal

**Files:**
- Modify: `install.sh` (`link`, the bashrc line, vim marker block)
- Modify: `setup.sh` (export `KIT_JOURNAL` in standalone)
- Test: `tests/t-standalone.sh`

**Interfaces:**
- Consumes: `KIT_MODE`, `KIT_DIR` (Task 1).
- Produces: `journal <type> <field>...` in install.sh (appends one
  TAB-separated line to `$KIT_JOURNAL`, no-op when unset). Later tasks
  read the format defined in File Structure.

- [ ] **Step 1: Add checks to `t-standalone.sh`:**
  - after install, `$KIT_DIR/.journal` has a `link` line for `~/.vimrc`
    whose 4th field is `~/.vimrc.local-backup` (the pre-existing file)
  - it has exactly one `line` entry, for `~/.bashrc`
  - after a second `setup.sh`, the journal is byte-identical (converged
    runs write nothing)
  - a PIE login (`t-install.sh` T2) still leaves no `.journal` anywhere
    under the AFS cell: append that check to T2.

- [ ] **Step 2: Run, expect FAIL** (no journal).

- [ ] **Step 3: Implement `journal()`; call it from `link` after a link
  is created (with the backup path, or empty) and after the bashrc line
  is appended.** Journal only actions that happened, never no-ops.

- [ ] **Step 4: Run all suites, expect PASS.**

- [ ] **Step 5: Commit** — `Journal what install.sh changes outside
  the kit home`.

### Task 3: `kit uninstall` (home part)

**Files:**
- Create: `uninstall.sh`
- Modify: `setup.sh` (`FILES` += `uninstall.sh`), `bashrc` (`kit
  uninstall`)
- Test: `tests/t-standalone.sh`, `tests/t-install.sh` (append T12)

**Interfaces:**
- Consumes: journal format; the AFS fixed set; `KIT_DIR`, `KIT_MODE`.
- Produces: `uninstall.sh` run as `sh "$KIT_DIR/uninstall.sh"` with
  `KIT_DIR` set; exit 0 when done or nothing to do, 1 when something
  was left in place (each left item printed as `[-] kept <path>: <why>`).
  `kit uninstall` in bashrc calls it. Task 6 adds the package step at a
  marked spot.

- [ ] **Step 1: Add checks.** In `t-standalone.sh`, snapshot before
  install with `find "$HOME" -printf '%p %y %l %s %m\n'` after dropping
  the runtime paths from Global Constraints, plus `sha256sum` of every
  regular file; then install, use the env (`bash -ic 'kit; cc99 --version'`,
  open and quit vim), uninstall, snapshot again:
  - snapshots identical
  - `~/.vimrc` content is `mine`
  - user's `~/.bashrc`, with `# above` added before and `# below` after
    the kit line after install: after uninstall it is the original plus
    exactly those two lines
  - run setup twice, then uninstall: same as above
  - a link repointed by the user (`ln -sfn /etc/hostname ~/.inputrc`)
    is kept and reported; exit 1
  - second `kit uninstall`: exit 0, prints `nothing to uninstall`

  In `t-install.sh`, T12 (PIE layout): `mkafs`, then copy `/cri`'s
  `bashrc vimrc install.sh` into `.confs/.confs.backup`'s place
  (`$AFS/.confs.backup/`, as setup.sh's first run does), log in once,
  run `uninstall.sh`; then `.confs` has the CRI files again (byte-identical
  to `/cri` for `bashrc vimrc install.sh`), `mozilla/` and `ssh/` with
  their test content untouched, no `bin`, `pylib`, `.kit`, `vim/pack/kit`;
  `~/.vimrc` is gone or links to the CRI vimrc.

- [ ] **Step 2: Run, expect FAIL** (no uninstall.sh).

- [ ] **Step 3: Implement `uninstall.sh`.**
  - Journal present: read it backwards. `link`: remove `dst` only if it
    still points to `src`; then, if the backup exists and `dst` is free,
    move it back. `line`: remove the exact line from the file (whole-line
    fixed-string match, file otherwise untouched). Then remove the kit
    home.
  - No journal, AFS layout (`$KIT_DIR` is `*/.confs`): remove the links
    in `$HOME` that point into the fixed set, remove the fixed set,
    move each file in `.confs.backup` back into `.confs`, remove
    `.confs.backup`. Never touch other files in `.confs`.
  - Neither: print `nothing to uninstall`, exit 0.

- [ ] **Step 4: Run all suites (dash, bash, busybox-ash for
  t-install), expect PASS.**

- [ ] **Step 5: Commit** — `kit uninstall: replay the journal, restore
  what the kit replaced`.

### Task 4: aarch64 binaries

**Files:**
- Modify: `setup.sh` (version/sha block, `fetch_bin` calls)
- Modify: `tests/run.sh` (`ARCH=amd64|arm64`, default amd64)

**Interfaces:**
- Produces: `ARCH=arm64 tests/run.sh t-standalone.sh` runs the suite on
  arm64 images.

- [ ] **Step 1: Add to `t-standalone.sh`:** every one of starship, fzf,
  rg, fd, bat, tldr in `$KIT_DIR/bin` runs `--version`, or setup's output
  has `<tool>: no build for <arch>, skipped`.

- [ ] **Step 2: Run with `ARCH=arm64`, expect FAIL** (x86_64 binaries,
  `Exec format error`).

- [ ] **Step 3: Implement.** One sha variable per tool and arch
  (`STARSHIP_SHA_X86_64`, `STARSHIP_SHA_AARCH64`, ...); the arch from
  `uname -m`; asset names per upstream release (ripgrep's aarch64 build
  is `-gnu`, not `-musl`: check each release page). Get each aarch64
  sha by downloading the asset and checking it against the upstream
  checksum file where the release publishes one. A tool without an
  aarch64 asset at the pinned version is skipped with the message above.

- [ ] **Step 4: Run with `ARCH=arm64` and `ARCH=amd64`, plus the PIE
  suites, expect PASS.**

- [ ] **Step 5: Commit** — `aarch64: pinned, verified binaries per
  architecture`.

### Task 5: System packages

**Files:**
- Create: `packages.sh`
- Modify: `setup.sh` (`FILES` += `packages.sh`; call it; sudo handoff)
- Test: `tests/t-standalone.sh`

**Interfaces:**
- Consumes: `KIT_JOURNAL`, `KIT_MODE`.
- Produces: `sh packages.sh install` (exit 0 always; prints what it did
  or the command to run). Journals `pkg` lines for every package present
  after and absent before.

- [ ] **Step 1: Add checks to `t-standalone.sh` (new section, run as
  root):**
  - root, `KIT_PACKAGES` unset, no tty: packages installed;
    `gcc`, `clangd`, `clang-format`, `gdb`, `valgrind`, `vim` on PATH;
    `cctest` builds a one-test criterion file and `./a.out` passes
  - the journal has a `pkg` line for `clangd` and none for `curl`
    (installed by the harness before)
  - as `student` with passwordless sudo, no tty, `KIT_PACKAGES` unset:
    nothing installed; output contains `sudo apt-get install` (or
    `pacman -S`) and the package list
  - same under `script -qc` (a tty) answering `y` on stdin of the tty:
    installed
  - `curl ... | sudo sh` as student (`SUDO_USER=student`): packages
    installed, kit home under `/home/student`, owned by `student`
  - ubuntu:22.04: output has the vim-older-than-9 warning; env still works
  - archlinux (no synced database): package step stops with
    `run: pacman -Syu`; home part still installed; setup exits 0

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement `packages.sh`.**
  - Manager: `apt-get` → apt, `pacman` → pacman, else print nothing and
    exit 0 (the PIE is NixOS: silent).
  - Package sets (verify each name exists on bookworm, noble, jammy and
    Arch; drop and report one that does not):
    apt: `build-essential gdb valgrind clangd clang-format
    libcriterion-dev lcov vim git curl python3 python3-pip tmux xsel
    binutils file`;
    pacman: `base-devel gdb valgrind clang criterion lcov vim git curl
    python python-pip tmux xsel binutils file`.
  - Policy, in order: `KIT_PACKAGES=no` → skip; `KIT_PACKAGES=yes` or
    root → install; `command -v sudo` succeeds and `/dev/tty` can be
    opened for reading → one `install these N packages? [y/N]` read from
    `/dev/tty`, then `sudo`; otherwise skip and print the command.
  - Snapshot: apt `dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n'`
    lines starting `ii`; pacman `pacman -Qq`. Journal the difference.
  - apt: `apt-get update` then `apt-get install -y
    --no-install-recommends`; pacman: `pacman -S --needed --noconfirm`,
    on failure print `run: pacman -Syu, then kit update` and continue.
  - vim older than 9.0 (`vim --version | head -1`): warn that LSP and
    snippets are off.
  - setup.sh: when root with `SUDO_USER` set, first run the home part
    as that user:
    `sudo -u "$SUDO_USER" -H sh -c 'curl -fsSL "$KIT_SETUP_URL" |
    KIT_PACKAGES=no sh'`, `KIT_SETUP_URL` defaulting to the master raw
    URL of setup.sh (the same URL `kit update` uses; tests point it at
    the local server). Then run `packages.sh` as root with
    `KIT_JOURNAL` set to that user's journal, and `chown` the journal
    back to the user.

- [ ] **Step 4: Run on debian:bookworm, ubuntu:24.04, ubuntu:22.04,
  archlinux (amd64), and debian/ubuntu arm64; plus the PIE suites.
  Expect PASS.**

- [ ] **Step 5: Commit** — `Standalone: install the system packages the
  kit relies on (apt, pacman)`.

### Task 6: Package removal on uninstall

**Files:**
- Modify: `uninstall.sh` (package step), `tests/t-standalone.sh`

**Interfaces:**
- Consumes: `pkg` journal lines; the policy from Task 5 (same rules for
  root / sudo / tty / `KIT_PACKAGES`).

- [ ] **Step 1: Add checks:** with `gdb` installed by the harness before
  setup, root install then uninstall: the installed package name list
  equals the snapshot from before setup (so `gdb` is still there and
  `clangd` is gone); a package journaled by the kit that a package
  installed afterwards depends on (install `clang-tidy` by hand after
  setup, which needs the kit's clang libs) is kept and reported.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.** apt: `apt-mark auto` on the journaled set,
  `apt-get -s autoremove` to list what is removable, purge the
  intersection with the set, report the rest. pacman: mark the set
  `--asdeps`, repeatedly remove `pacman -Qdtq` ∩ set until it is empty,
  report the rest. Runs before the home part is removed.

- [ ] **Step 4: Run the full matrix of Task 5 Step 4, expect PASS.**

- [ ] **Step 5: Commit** — `kit uninstall: remove only the packages the
  kit installed`.

### Task 7: Docs and release

**Files:**
- Modify: `README.md` (an "Anywhere" section: the one-liner, what root
  adds, `kit uninstall`, supported distros and arches), `cheatsheet`
  (`kit uninstall` under `kit`), `tests/run.sh` (header: the new suite,
  `IMAGE=`, `ARCH=`)

- [ ] **Step 1: Write the docs.** Cheatsheet lines keep the existing
  two-column layout (`kit` renders columns 3-28 and 31+).
- [ ] **Step 2: Run everything once more** (`tests/run.sh`, then the
  standalone matrix), expect PASS.
- [ ] **Step 3: Commit, then bump PIN** to that commit in a separate
  `Release: bump PIN` commit, as the repo does. Do not push.

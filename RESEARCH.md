# PIE environment research: definitive report

Audience: maintainer of the `pie/` starter kit for ING1 C-piscine students.
Scope: what to run day to day on the PIE, what to memorize for exams, and
concrete changes to the kit files, all grounded in probes of the real
`nixos-pie` docker image (the actual PIE userland) plus 2025-2026 community
sources.

Legend: **[CONFIRMED]** = verified against the real image in this research
cycle (adversarially re-verified). **[sourced]** = from documentation or
community writing, not exercised in the image. **[UNVERIFIED]** = a known gap,
listed in section 6.

---

## 1. Executive advice: day-to-day setup

### Editor: plain vim 9.2, vim-first, no neovim

- The image ships vim-full 9.2.0340 only; neovim is absent from PATH and the
  entire /nix/store **[CONFIRMED]**. Exam images have a read-only store and no
  network, so vim is the only modal editor that exists on exam day.
- Vim 9.2 on PIE is unusually capable: +clipboard/+xterm_clipboard,
  +terminal, +python3, +persistent_undo, +packages, and `$VIMRUNTIME/pack/dist/opt`
  ships comment, matchit, termdebug, osc52, editorconfig, hlyank and more
  **[CONFIRMED]**. `packadd comment` gives gcc/gc commenting, `packadd
  termdebug` gives a split-window gdb UI, `runtime ftplugin/man.vim` gives
  `:Man malloc` for offline man pages: all zero-install, all exam-available
  **[CONFIRMED]**.
- Critical mechanic: creating ANY user vimrc silently disables
  `$VIMRUNTIME/defaults.vim`, losing incsearch, scrolloff=5, mouse, ttimeout
  and `filetype plugin indent on` **[CONFIRMED]** (probed: incsearch=0,
  scrolloff=0 without re-sourcing). Every vimrc, full or exam, must start
  with `source $VIMRUNTIME/defaults.vim`. The current `pie/vimrc.exam` gets
  this wrong (see section 3).
- The nixpkgs system vimrc already does `set nocompatible` and `syntax on`
  **[CONFIRMED]**, and wildmenu is compiled-on even with `-u NONE`
  **[CONFIRMED]**, so those lines are cargo cult and cost memorization budget.
- Neovim is a legitimate optional extra on normal days:
  `nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#neovim`
  installs NVIM v0.12.4 from cache.nixos.org, and its built-in
  `vim.lsp.enable('clangd')` plus `vim.pack` need zero plugins (clangd and
  bear ship at /bin) **[CONFIRMED]**. But it vanishes at reboot and never
  exists on exams, so it must not become load-bearing. Distros (LazyVim,
  NvChad) are wrong for this cohort **[sourced]**: they train an editor shape
  that does not exist on exam day.
- Other exam-day editors exist and are worth knowing about as fallbacks:
  nano 8.7, Emacs 30.2 (with OCaml modes), VSCodium 1.106 with cpptools,
  cmake-tools and the vscodevim extension pre-bundled, and CLion 2025.3.1,
  all in the read-only store **[CONFIRMED]**. The kit still teaches vim, but
  a student who freezes in vim has codium with vim emulation available
  offline.

### Shell: configured bash 5.3, no zsh

- zsh, fish, and every other shell are absent from the entire store; no
  /etc/shells, so zsh cannot be a login shell even if nix-installed
  **[CONFIRMED]**. bash 5.3.3 is the only realistic choice, and it closes
  most of the zsh gap with ~30 lines:
  - git-aware prompt and git completion come dependency-free from git 2.51's
    own contrib scripts at
    `"$(git --exec-path)/../../share/git/contrib/completion/"`; sourcing
    them defines `__git_ps1` and `__git_complete` **[CONFIRMED]**. This works
    on exam images too, since git is in the read-only store.
  - readline via ~/.inputrc reproduces zsh's completion feel: TAB
    menu-complete, colored-stats, completion-ignore-case,
    menu-complete-display-prefix, and prefix history search on the arrow
    keys, all active in the image's bash **[CONFIRMED]**.
  - `shopt -s autocd globstar histappend cdspell dirspell` all work in bash
    5.3.3 **[CONFIRMED]**.
- What bash cannot replicate: autosuggestion ghost text and live syntax
  highlighting **[sourced]**. 2025-2026 consensus already treats oh-my-zsh
  as legacy bloat; the delta is smaller than its reputation, and here every
  exam drops you back into bash anyway. Verdict: train the graded
  environment.
- bash-completion 2.x is NOT installed (only nix-command completions and a
  grub snippet) **[CONFIRMED]**. git completion is covered by git's contrib
  script; full bash-completion is a normal-day nice-to-have via
  `nix profile add nixpkgs#bash-completion`, always behind a `[ -r ... ]`
  guard so exams degrade gracefully.

### CLI tools: tmux first, fzf as sugar, skip the rest

- tmux 3.6a is preinstalled and honors `~/.config/tmux/tmux.conf`
  **[CONFIRMED]** (history-limit 100000 and mouse on verified via
  `tmux show -g`). A 5-line config is the single highest value-per-cost item
  and short enough to retype on exam day:
  `set -g mouse on` / `set -g history-limit 100000` / `set -g base-index 1` /
  `setw -g mode-keys vi` / `set -g escape-time 10`.
- fzf, ripgrep, zoxide install cleanly on normal sessions
  (`nix profile add nixpkgs#fzf nixpkgs#ripgrep nixpkgs#zoxide`, versions
  0.74.2 / 15.2.0 / 0.10.0 from cache) and fzf's `--bash` integration works
  **[CONFIRMED]**. Only fzf (ctrl-r history) and optionally ripgrep earn
  their place; teach `grep -rn` first because that is what exams have.
- Skip as hype for this audience: starship (3 lines of PS1 replace it),
  bat, delta, eza, zoxide **[sourced]**. Each builds muscle memory that
  betrays the student on exam day.
- Strategic principle for the whole kit: preinstalled tools (vim+termdebug,
  tmux, grep -rn, gdb, rr, git, tree) are the primary workflow;
  nix-installed extras are accelerators layered on by install.sh, never
  dependencies.

### Debugging: sanitizers first, then a 12-command gdb vocabulary

- The moulinette grades with ASAN (75% malus), so the default dev build is
  sanitized. Verified in the image: ASAN reports heap-buffer-overflow with
  exact file:line, and UBSAN with `UBSAN_OPTIONS=print_stacktrace=1` prints
  a full stack for signed overflow **[CONFIRMED]**.
- Segfault triage one-liner: `gdb -batch -ex run -ex 'bt full' ./prog`
  **[sourced, gdb 16.3 with TUI and Python 3.13 CONFIRMED present]**.
- The 4-line gdbinit (print pretty, confirm off, pagination off, history
  save) is read and applied by gdb 16.3 **[CONFIRMED]**. The kit's existing
  `pie/gdbinit` already matches; keep it.
- Normal days: gdb-dashboard (single-file .gdbinit) downloads and renders
  its full dashboard against the image's gdb **[CONFIRMED]**. Skip
  GEF/pwndbg (exploitation-focused) **[sourced]**. Exam fallback: built-in
  TUI (`layout src`, Ctrl-X A, Ctrl-L) and vim termdebug.
- rr 5.9 ships **[CONFIRMED present]**; the `watch -l addr` +
  `reverse-continue` recipe is the canonical root-cause workflow for
  wrong-value bugs **[sourced]**, but recording needs hardware perf counters
  that docker cannot prove: see gap G4.
- valgrind 3.26 is the second opinion on non-ASAN builds
  (`--leak-check=full --track-origins=yes`); ASAN and valgrind are mutually
  exclusive **[CONFIRMED present / sourced behavior]**.
- Teaching order for beginners: 1 fix all warnings, 2 ASAN/UBSAN report,
  3 gdb batch backtrace, 4 interactive gdb/termdebug, 5 rr.

### Criterion (grading tests): fully present and frictionless

- Criterion v2.4.2 ships with headers, shared and static libs, and
  pkg-config **[CONFIRMED]**. Plain `gcc t.c -lcriterion -o t` compiles and
  the binary runs 2/2 tests directly, because the PIE gcc wrapper
  auto-applies -I/include and -L/lib **[CONFIRMED]**. This closes the
  critic's criterion gap: students can compile and run criterion suites
  locally with zero flags beyond `-lcriterion`, on normal and exam images.

---

## 2. The exam playbook: exactly what to memorize

Everything below uses only the read-only store and is typed from memory at
exam start. Budget: about 2 minutes total.

### 2.1 The one reconciled exam vimrc (replaces the three drafts)

The research bundle produced three conflicting exam vimrcs. Reconciliation
rules applied: (a) the defaults.vim re-source is mandatory, since any user
vimrc kills incsearch/scrolloff/mouse **[CONFIRMED]**; (b) drop everything
the system vimrc or defaults.vim already sets: nocompatible, syntax on,
filetype plugin indent on, incsearch, mouse, wildmenu **[CONFIRMED
redundant]**; (c) keep the EPITA-specific style-malus guards from the
epita-community angle (cc=80, listchars, Makefile noexpandtab); (d) keep the
zero-install power features (packadd trio, :Man, undofile).

The canonical 7-line exam vimrc:

```vim
source $VIMRUNTIME/defaults.vim
set nu et sw=4 sts=4 cc=80 cin
set hls ic scs hidden undofile undodir=/tmp
set list listchars=tab:>-,trail:-
autocmd Filetype make setlocal noexpandtab
packadd comment | packadd matchit | packadd termdebug
runtime ftplugin/man.vim
```

Every line justified:
- Line 1: restores incsearch, scrolloff=5, mouse, ttimeout, filetype
  plugin indent on, last-cursor-position **[CONFIRMED]**. Highest-value line.
- Line 2: numbers, EPITA 4-space indent (clang-format malus relevant),
  80-column marker, cindent. Short option names are deliberate.
- Line 3: hlsearch, smartcase search, buffer switching with unsaved
  changes, undo that survives closing a file within the session; /tmp
  undodir keeps %-files out of the submission repo **[CONFIRMED writes the
  undo file]**.
- Line 4: makes tab characters and trailing whitespace visible, the two
  documented style-malus traps **[sourced: Trove, epita-default-confs]**.
- Line 5: protects Makefiles from expandtab (make requires real tabs).
- Line 6: gcc/gc commenting **[CONFIRMED: maparg('gcc') returns
  <Plug>(comment-toggle-line)]**, % on #if/#endif, and :Termdebug
  **[CONFIRMED: exists(':Termdebug')==2]**.
- Line 7: `:Man malloc` offline man pages **[CONFIRMED:
  exists(':Man')==2]**, replacing the missing internet.

Optional extras if memory allows: `set path+=**` (then `:find name`), and
`set cb=unnamedplus` for system clipboard (vim has +clipboard/+X11
compiled in **[CONFIRMED]**, but see gap G5 on live-session clipboard).

### 2.2 The bash exam kernel (6 lines)

```sh
. "$(git --exec-path)/../../share/git/contrib/completion/git-prompt.sh"
PS1='\u \[\e[1;34m\]\w\[\e[0m\]$(__git_ps1)\$ '
HISTSIZE=100000
shopt -s autocd globstar histappend
bind '"\e[A": history-search-backward'; bind '"\e[B": history-search-forward'
alias cw='gcc -std=c99 -Wall -Wextra -Werror -pedantic -g3 -fsanitize=address,undefined'
```

The git contrib path resolves through the git derivation itself, so it is
hash-independent and works on exam images **[CONFIRMED: sourcing defines
__git_ps1]**. See gap G6 on whether exam terminals source ~/.bashrc.

### 2.3 The compile alias, reconciled

The bundle had three variants. Union of intents, one line:
`gcc -std=c99 -Wall -Wextra -Werror -pedantic -g3 -fsanitize=address,undefined`.
Rationale: -Werror matches the moulinette's build discipline, ASAN matches
its grading, UBSAN is free and catches signed overflow, -g3 maximizes debug
info. Both sanitizers verified working with exact file:line output
**[CONFIRMED]**. The exact moulinette flag set remains unverified (gap G2);
these flags are a strict superset of every claimed variant, which is the
safe direction (stricter locally than the grader).

Environment knobs: `export UBSAN_OPTIONS=print_stacktrace=1` always;
`ASAN_OPTIONS=abort_on_error=1` when running under gdb;
`ASAN_OPTIONS=detect_leaks=0` to silence leak noise temporarily
**[CONFIRMED for print_stacktrace; others sourced from google/sanitizers]**.

### 2.4 The gdb vocabulary (12 commands plus 2 one-liners)

start, `b file:line`, run, n, s, finish, c, `bt full`, frame/up/down,
`p expr`, `display expr`, `watch var` / `watch -l addr`, q.
One-liners: `gdb -batch -ex run -ex 'bt full' ./prog` and
`gdb --args ./prog a b`. The 4-line gdbinit from section 1 if time allows.
In-vim alternative: `:packadd termdebug`, `:Termdebug ./prog`, then
:Break, :Over, :Step, :Continue, :Finish, K to evaluate **[CONFIRMED
loadable; sourced for the interactive session, see G5]**.

### 2.5 Style gate and submission ritual

- Manual pre-submit check: `clang-format --Werror --dry-run file.c` exits
  nonzero on violations **[CONFIRMED: exit 1 on a misformatted file]**.
- Format everything: `find . -name '*.[ch]' -exec clang-format -i {} \;`
  **[CONFIRMED it runs and reformats]**, but ONLY with a `.clang-format` at
  repo root: without one, clang-format falls back to LLVM style, which is
  not verified to match EPITA style (gap G1). The kit's vimrc already uses
  `--style=file --fallback-style=none`, which is the correct defensive
  posture.
- Tag and push: `git tag -a name -m msg && git push --follow-tags`
  **[sourced: Trove "Submission For Dummies"; forgotten tag pushes are the
  classic pitfall]**.

### 2.6 tmux (5 lines, only if wanted)

The section 1 config, typed into `~/.config/tmux/tmux.conf`. tmux ships in
the read-only store **[CONFIRMED]**.

---

## 3. Concrete proposed changes to pie/

### 3.1 pie/vimrc.exam: rewrite (bug: missing defaults.vim source)

The current file's header comment claims "defaults.vim already gives:
syntax, filetype indent, incsearch, wildmenu, ruler, backspace, mouse" and
then omits sourcing it. This is wrong twice: (a) the moment vimrc.exam is
written to ~/.vimrc, defaults.vim stops loading entirely **[CONFIRMED]**, so
incsearch and mouse are silently lost; (b) this defaults.vim version does
not set ruler, and wildmenu comes from compiled defaults, not defaults.vim
**[CONFIRMED]**. Replace the whole file with:

```vim
" EPITA exam vimrc - type from memory at exam start (vim ~/.vimrc).
" Line 1 is mandatory: any user vimrc suppresses defaults.vim entirely
" (losing incsearch, scrolloff, mouse, filetype indent) unless re-sourced.
source $VIMRUNTIME/defaults.vim
set nu et sw=4 sts=4 cc=80 cin
set hls ic scs hidden undofile undodir=/tmp
set list listchars=tab:>-,trail:-
autocmd Filetype make setlocal noexpandtab
packadd comment | packadd matchit | packadd termdebug
runtime ftplugin/man.vim
```

Update the README "Exams" section to match (it currently shows the old
3-liner and repeats the same wrong claim about defaults.vim).

### 3.2 pie/vimrc: small additive changes

Current file is good. Proposed deltas, each justified:

```vim
" At the very top, before everything else:
source $VIMRUNTIME/defaults.vim
```
Restores ttimeout tuning, last-cursor-position autocmd, and keeps the full
vimrc a superset of the exam vimrc so muscle memory transfers 1:1
**[CONFIRMED mechanic]**. The file's own settings then override where they
differ (e.g. it remaps Q).

```vim
" With the existing packadd! termdebug:
packadd! comment
packadd! matchit
runtime ftplugin/man.vim
set path+=**
set wildoptions=pum
set list listchars=tab:>-,trail:-
autocmd Filetype make setlocal noexpandtab
```
comment/matchit/:Man are zero-cost **[CONFIRMED loadable]**; `path+=**`
enables `:find` navigation (no fzf on the image); wildoptions=pum is the
modern popup completion menu; listchars complements the existing
ExtraWhitespace highlight by also exposing tab characters (the highlight
only catches trailing whitespace); the make autocmd protects Makefiles from
the global expandtab, a real breakage risk in the current file.

Remove `set wildmenu` from the wildmenu line if simplifying (compiled-on
**[CONFIRMED]**), keep `wildmode`.

Note: `clang-format-epita` referenced by `:Format` was not observed in the
image probe facts; keep the `executable()` guard (already present) and
verify on real PIE (gap G1).

### 3.3 pie/bashrc: upgrade prompt and add verified git integration

Replace the `__branch` prompt block with the verified git contrib version
(keeps colors, adds dirty-state markers and git completion), guarded so a
missing git can never break a login shell:

```sh
GITC="$(git --exec-path 2>/dev/null)/../../share/git/contrib/completion"
if [ -r "$GITC/git-prompt.sh" ]; then
    . "$GITC/git-prompt.sh"
    [ -r "$GITC/git-completion.bash" ] && . "$GITC/git-completion.bash"
    GIT_PS1_SHOWDIRTYSTATE=1 GIT_PS1_SHOWUNTRACKEDFILES=1 GIT_PS1_SHOWCOLORHINTS=1
    PROMPT_COMMAND='__git_ps1 "\[\e[36m\]\w\[\e[0m\]" " \$ " " (%s)"'
else
    __branch() { git branch --show-current 2>/dev/null | sed 's/.*/ (&)/'; }
    PS1='\[\e[36m\]\w\[\e[33m\]$(__branch)\[\e[0m\] \$ '
fi
```
The 3-arg PROMPT_COMMAND form is required for color hints **[CONFIRMED:
renders branch, dirty asterisk, and colors in a dirty repo]**. The fallback
is the current prompt, unchanged.

Other deltas: raise HISTSIZE/HISTFILESIZE to 100000; add
`shopt -s globstar autocd`; add
`export UBSAN_OPTIONS=print_stacktrace=1`; extend `ccsan` to
`-fsanitize=address,undefined` (section 2.3). Note the current `cctest`
alias puts `-lcriterion` before the source file in expanded commands; it
works here because the alias is a prefix and sources come after, but
libraries-after-objects is the safe idiom: prefer documenting
`gcc t.c -lcriterion -o t` **[CONFIRMED working with zero extra flags]**.

### 3.4 New file pie/inputrc, linked by install.sh

```
set completion-ignore-case on
set show-all-if-ambiguous on
set menu-complete-display-prefix on
set colored-stats on
set colored-completion-prefix on
set mark-symlinked-directories on
set skip-completed-text on
set bell-style none
"\e[A": history-search-backward
"\e[B": history-search-forward
TAB: menu-complete
"\e[Z": menu-complete-backward
```
All settings confirmed active via `bind -v` / `bind -q` in the image's bash
**[CONFIRMED]**. Highest leverage-per-line file in the kit; also improves
gdb and python3 line editing since readline is shared. Add `link inputrc`
to install.sh.

### 3.5 New file pie/tmux.conf, special-cased in install.sh

```
set -g mouse on
set -g history-limit 100000
set -g base-index 1
setw -g mode-keys vi
set -g escape-time 10
```
**[CONFIRMED honored at ~/.config/tmux/tmux.conf]**. install.sh's `link()`
only handles `~/.<name>`; add one special case:

```sh
mkdir -p "$HOME/.config/tmux" 2>/dev/null
[ -e "$DOT/tmux.conf" ] && ln -sfn "$DOT/tmux.conf" "$HOME/.config/tmux/tmux.conf"
```
(tmux 3.6 also reads ~/.tmux.conf, so `link tmux.conf` naming would need a
rename; the ~/.config path keeps the kit tidy.)

### 3.6 pie/install.sh: optional nix extras, defensively

Append after the links, before `exit 0`:

```sh
# Optional normal-day extras; must never delay or fail a login.
if [ "${PIE_NIX_EXTRAS:-0}" = 1 ] && command -v nix >/dev/null 2>&1; then
    [ -n "${NIX_SSL_CERT_FILE:-}" ] || export NIX_SSL_CERT_FILE=$(echo /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)
    nix --extra-experimental-features 'nix-command flakes' \
        profile add nixpkgs#fzf nixpkgs#bash-completion >/dev/null 2>&1 &
fi
```
Backgrounded, opt-in via a flag file or env, silent on failure: satisfies
the login-safety contract test.bats enforces. `nix profile add` end-to-end
and the SSL cert defense are **[CONFIRMED]**; per-login cost after first
cache pull is seconds **[sourced/partially observed]**. Pair with guarded
sourcing in bashrc:
`[ -r ~/.nix-profile/share/fzf/key-bindings.bash ] && . ~/.nix-profile/share/fzf/key-bindings.bash`
(fzf ships that file **[CONFIRMED]**) and the equivalent for
bash-completion. Exams simply skip all of it.

### 3.7 pie/gdbinit: keep as is; optional dashboard

The existing 5-line file matches the verified minimal config
**[CONFIRMED gdb reads and applies it]**. Optionally vendor a cached copy of
gdb-dashboard's .gdbinit (2389 lines, single file, loads cleanly against
the image's Python-enabled gdb **[CONFIRMED]**) into AFS as an opt-in
(`gdb -x ~/afs/.confs/gdb-dashboard.gdbinit`), rather than replacing the
default: beginners should learn plain gdb output first.

### 3.8 pie/README.md: documentation deltas

- Rewrite the Exams section around the 7-line vimrc.exam and the bash exam
  kernel; fix the defaults.vim claim.
- Add the criterion one-liner (`gcc t.c -lcriterion -o t`) and the
  sanitizer teaching order.
- Add the submission ritual (clang-format gate + `git push --follow-tags`).
- State the strategic principle: preinstalled tools are the workflow,
  nix extras are sugar.

---

## 4. Researched and rejected (do not relitigate)

| Rejected | Reason |
|---|---|
| zsh + oh-my-zsh / zimfw | No zsh anywhere in the store, no /etc/shells, cannot be login shell **[CONFIRMED]**; per-session install only; community itself calls omz legacy bloat; exam muscle-memory risk. |
| starship | Absent; replaced by git-prompt.sh / 3-line PS1 that also works on exams **[CONFIRMED]**. |
| neovim as primary editor | Absent from image **[CONFIRMED]**; installable per session only; exam images have vim only. Optional normal-day extra at most. |
| LazyVim / NvChad distros | Hide the editor, maintenance concerns, produce helplessness on exam day **[sourced]**. Point motivated students at kickstart.nvim or mini.nvim after the piscine. |
| Vim LSP client in the default kit | No client ships in $VIMRUNTIME; needs AFS or nix install; unavailable on exams, so must not shape daily habits. clangd+bear are present for those who opt in **[CONFIRMED present]**. |
| zoxide, bat, delta, eza | Solve problems piscine students do not have; duplicate less/vim/ls; exam-absent habits **[sourced]**. |
| GEF / pwndbg | Exploitation-focused, noisy for beginner C; gdb-dashboard is the right visual layer if any **[sourced; dashboard CONFIRMED working]**. |
| bash-completion as hard dependency | Package absent from image **[CONFIRMED]**; git contrib scripts cover the case that matters; full package is a guarded nix extra only. |
| Vundle/plugin vimrcs (older EPITA repos) | Need network installs; vim 9.2 built-in packages cover commenting, matching, debugging **[CONFIRMED]**. |
| Redundant vimrc lines (nocompatible, syntax on, filetype..., incsearch, mouse, wildmenu) | Already set by system vimrc, defaults.vim, or compiled defaults **[CONFIRMED]**; waste exam memorization budget. |
| micro / helix / kakoune | Absent from image **[CONFIRMED]**; same exam objection as neovim, smaller ecosystems. |

---

## 5. Critic's gaps: resolution status

- G0 (three conflicting exam vimrcs): RESOLVED. Reconciled in section 2.1;
  the two drafts missing the defaults.vim source were wrong, and their
  redundant lines were dropped per the confirmed redundancy list.
- G1 (moulinette clang-format style): OPEN, [UNVERIFIED]. Nobody confirmed
  whether piscine/exam repos ship a .clang-format or whether bare LLVM style
  passes. Mitigation adopted: always format with `--style=file
  --fallback-style=none`, never bare `clang-format -i` without a repo
  config; verify `clang-format-epita` existence on real PIE. Action: check a
  real piscine repo for .clang-format and diff EPITA style vs LLVM default.
- G2 (exact moulinette gcc flags): OPEN, [UNVERIFIED]. Resolved
  pragmatically by unioning the three variants into one strict superset
  (section 2.3): compiling stricter than the grader is fail-safe. Action:
  read a real moulinette trace output for the actual flags.
- G3 (three conflicting gcc aliases): RESOLVED by G2's union line; kit keeps
  cc99/ccsan names with ccsan upgraded to address,undefined.
- G4 (rr perf counters on real PIE): OPEN, [UNVERIFIED], untestable in
  docker. Mitigation: README tells students to run `rr record /bin/ls` once
  on real hardware; fallback is plain gdb watchpoints. rr binary itself
  confirmed present.
- G5 (all probes headless): ACKNOWLEDGED. "+y clipboard, tmux mouse,
  termdebug interactive sessions, and readline menu UX were verified at the
  load/setting level only, never in a live terminal with X. The harness's
  `./harness.sh gui` (i3 under Xwayland) exists precisely to close this;
  action: one manual gui session exercising "+y, xsel, :Termdebug and tmux
  mouse.
- G6 (shell startup order on real PIE): PARTIALLY OPEN. The probed image
  has no /etc/bashrc **[CONFIRMED]**, and the harness's `bash -i` login path
  applies the kit's PS1 (test.bats passes), but whether real PIE terminal
  emulators start login vs non-login shells, and whether NixOS profile
  scripts reset PS1 afterward, was not probed on metal. Mitigation already
  in place: keep ~/.bash_profile sourcing ~/.bashrc if needed; action: run
  `shopt login_shell; echo $PS1` in a real PIE terminal once.
- G7 (install.sh nix cost/idempotency): PARTIALLY RESOLVED. The kit's
  install.sh and harness exist and are bats-tested for idempotency and
  login safety; the proposed nix-extras step (3.6) is backgrounded, opt-in,
  and silent-on-failure by construction. Cache-miss first-login cost and
  offline degradation on real PIE remain unmeasured [UNVERIFIED].
- G8 (criterion availability): RESOLVED, **[CONFIRMED]**. v2.4.2 present
  with headers/libs/pkg-config; `gcc t.c -lcriterion -o t` works with zero
  extra flags; binary runs directly. Documented in sections 1 and 3.8.

---

## 6. Sources

Empirical (highest authority, all CONFIRMED items):
- Probes of the local `nixos-pie` docker image (the real PIE userland):
  vim-full 9.2.0340, bash 5.3.3, git 2.51.2, gcc 14.3, gdb 16.3
  (Python 3.13), rr 5.9, valgrind 3.26, tmux 3.6a, criterion 2.4.2,
  nix 2.31.5, clangd/bear present, plus adversarial re-verification of all
  24 testable claims across the six research angles (all CONFIRMED).

Vim:
- https://batsov.com/articles/2026/02/22/how-to-vim-build-your-vimrc-from-scratch/
- https://github.com/romainl/minivimrc and idiomatic-vimrc
- https://vimtricks.wiki/posts/packadd-load-optional-packages
- https://vimhelp.org/terminal.txt.html#terminal-debug

Neovim landscape:
- https://gpanders.com/blog/whats-new-in-neovim-0-11/
- https://xnacly.me/posts/2025/neovim-lsp-changes/ and clangd-lsp
- https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
- Neovim 0.12 release coverage (alternativeto.net, heise.de, 2026-03)
- https://github.com/LazyVim/LazyVim/discussions/7024
- https://github.com/nvim-mini/mini.nvim
- linkarzu.com lazyvim-vs-kickstart; samuellawrentz.com 2026 retrospective

Shell:
- https://rushter.com/blog/zsh-shell/
- https://jpk.io/dev-tools/why-i-quit-oh-my-zsh/
- https://magnus919.com/notes/oh-my-zsh-alternatives/
- git contrib git-prompt.sh header documentation
- wicksipedia.com zsh startup; dev.to Starship-in-2026; glukhov.org git prompt

CLI tools:
- https://github.com/junegunn/fzf
- 2025-2026 modern-CLI roundups (dev.to, nexasphere.io, linuxteck.com)

Debugging:
- https://github.com/cyrus-and/gdb-dashboard
- https://github.com/google/sanitizers/wiki/AddressSanitizerFlags
- Red Hat Developer rr guide; undo.io time-travel debugging; MangaD 2025 rr
  guide; UIUC ECE220 fa2025 and UMN CSCI 2021 gdb references
- https://sourceware.org/gdb/current/onlinedocs/gdb/TUI.html

EPITA community:
- https://trove.assistants.epita.fr/docs/Editor/vim/ , /docs/piscine/ ,
  /docs/pre-commit/ , /docs/42sh/submission_for_dummies/
- https://github.com/epita/epita-default-confs (vimrc)
- https://github.com/pp5x/epita-ing1-prep
- EPITA coding style PDF (lrde.epita.fr); nixpie MR 53 (gitlab.cri.epita.fr)
- 42-piscine guides: codequoi.com, kristofk.com

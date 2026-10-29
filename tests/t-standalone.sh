#!/bin/bash
# setup.sh on a plain distro (no AFS, no PIE): the standalone layout under
# ~/.local/share/epita-kit. Starts as root in a stock image (IMAGE= in
# run.sh), installs what a fresh machine lacks, checks the system package
# step (P), then re-runs itself as an unprivileged user for the home
# checks (A). Configs are served from /kit (PIE_BASE), standing in for
# raw.githubusercontent.com at the PIN.
pass=0 fail=0
ok()  { pass=$((pass+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
ko()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
chk() { local m=$1; shift; if "$@"; then ok "$m"; else ko "$m"; fi; }
not() { ! "$@"; }
on_path() { command -v "$1" >/dev/null; }

if [ "$(id -u)" = 0 ]; then
    if command -v apt-get >/dev/null; then
        PM=apt
        apt-get update -qq && DEBIAN_FRONTEND=noninteractive \
            apt-get install -y -qq --no-install-recommends curl \
            ca-certificates python3 git sudo vim gdb >/dev/null
    elif command -v pacman >/dev/null; then
        PM=pacman
        # pacman's syscall sandbox (seccomp) fails under qemu emulation
        sed -i 's/^#DisableSandboxSyscalls/DisableSandboxSyscalls/' \
            /etc/pacman.conf
        pacman -Sy --noconfirm --needed curl ca-certificates python git \
            sudo vim gdb diffutils >/dev/null
    fi || { echo "cannot install test prerequisites"; exit 1; }
    useradd -m -s /bin/bash student || exit 1
    echo 'student ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/student
    (cd /kit && exec python3 -m http.server 8000 >/dev/null 2>&1) &
    sleep 1
    export PIE_BASE=http://localhost:8000
    as_student() { sudo -u student -H env PIE_BASE=$PIE_BASE "$@"; }

    # the package names installed, gdb among them: the user's own
    if [ $PM = apt ]; then
        pkgs() { dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' \
                     | awk '$1 == "ii" { print $2 }' | sort -u; }
    else
        pkgs() { pacman -Qq | sort -u; }
    fi
    pkgs > /tmp/pkgs0

    echo "== packages [$(. /etc/os-release && echo "$ID $VERSION_ID")]"
    if [ $PM = pacman ]; then
        echo "-- P0 archlinux, no synced package database"
        rm -f /var/lib/pacman/sync/*
        sh /kit/setup.sh > /tmp/pout 2>&1 </dev/null; rc=$?
        chk "exit 0" [ $rc = 0 ]
        chk "package step stops: run: pacman -Syu" \
            grep -q 'run: pacman -Syu' /tmp/pout
        chk "home part still installed" \
            [ "$(readlink ~/.vimrc)" = ~/.local/share/epita-kit/vimrc ]
        pacman -Sy >/dev/null 2>&1
    fi

    echo "-- P1 root, no tty: packages installed"
    sh /kit/setup.sh > /tmp/pout 2>&1 </dev/null; rc=$?
    chk "exit 0" [ $rc = 0 ]
    [ $rc = 0 ] || cat /tmp/pout
    for c in gcc clangd clang-format gdb valgrind vim; do
        chk "$c on PATH" on_path $c
    done
    mkdir -p /tmp/ct
    printf '%s\n' '#include <criterion/criterion.h>' \
        'Test(kit, works) { cr_assert(1); }' > /tmp/ct/t.c
    # bounded: criterion's a.out can hang under x86_64 emulation (seen on
    # ubuntu:24.04 amd64 on an arm64 host, not when run natively)
    criterion_runs() {
        bash -ic 'cd /tmp/ct && cctest t.c && timeout -s KILL 120 ./a.out' \
            >/dev/null 2>&1 </dev/null
    }
    chk "cctest builds a criterion test, ./a.out passes" criterion_runs
    TAB=$(printf '\t') J=~/.local/share/epita-kit/.journal
    clangd=clangd; [ $PM = pacman ] && clangd=clang
    chk "journal: pkg line for $clangd" grep -qxF "pkg$TAB$PM$TAB$clangd" "$J"
    chk "journal: no pkg line for curl (had it before)" \
        not grep -q "^pkg$TAB$PM${TAB}curl$" "$J"
    vimv=$(vim --version | sed -n '1s/^VIM - Vi IMproved \([0-9]*\).*/\1/p')
    if [ "$vimv" -lt 9 ]; then
        chk "vim $vimv: warned, LSP and snippets off" \
            grep -q 'LSP and snippets are off' /tmp/pout
    else
        chk "vim $vimv: no old-vim warning" \
            not grep -q 'LSP and snippets are off' /tmp/pout
    fi
    chk "env works (kit cheatsheet)" \
        grep -q 'EPITA PIE kit' <<<"$(bash -ic kit 2>/dev/null </dev/null)"

    echo "-- P2 sudo user, no tty: nothing installed, the command printed"
    # one kit package missing again, for the plain user's runs
    if [ $PM = apt ]; then apt-get purge -y -qq tmux >/dev/null
    else pacman -R --noconfirm tmux >/dev/null; fi
    H=$(as_student mktemp -d)
    as_student HOME="$H" sh /kit/setup.sh > /tmp/pout 2>&1 </dev/null; rc=$?
    chk "exit 0" [ $rc = 0 ]
    chk "tmux still not installed" not on_path tmux
    cmd="sudo apt-get install"; [ $PM = pacman ] && cmd="sudo pacman -S"
    chk "prints: $cmd ... tmux" grep -q "$cmd.* tmux" /tmp/pout

    echo "-- P3 sudo user on a terminal, answers y"
    printf 'y\n' | as_student HOME="$H" \
        script -qc 'sh /kit/setup.sh' /dev/null > /tmp/pout 2>&1; rc=$?
    chk "exit 0" [ $rc = 0 ]
    chk "asked once" [ "$(grep -c 'install these 1 packages? \[y/N\]' \
        /tmp/pout)" = 1 ]
    chk "tmux installed" on_path tmux

    echo "-- P4 curl | sudo sh: refused, run it as yourself"
    as_student sh -c 'curl -fsSL $PIE_BASE/setup.sh | sudo sh' \
        > /tmp/pout 2>&1 </dev/null; rc=$?
    chk "exit 1" [ $rc = 1 ]
    chk "says: run it as yourself" grep -q \
        'run it as yourself: the kit asks for sudo when it needs it' /tmp/pout

    echo "-- P5 root uninstall: the kit's packages go, the user's stay"
    # installed by hand after setup, it needs some of the kit's packages
    # (clang-tidy: the clang libs; lldb: clang-libs, llvm-libs)
    if [ $PM = apt ]; then
        dep=clang-tidy
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            --no-install-recommends $dep >/dev/null
    else
        dep=lldb
        pacman -S --noconfirm --needed $dep >/dev/null
    fi
    # and nothing else needs it (pulled in by a recommends): still the
    # user's, uninstall must not take it along with the kit's packages
    if [ $PM = apt ]; then apt-mark auto $dep >/dev/null
    else pacman -D --asdeps $dep >/dev/null; fi
    awk -F "$TAB" '$1 == "pkg" { print $3 }' "$J" | sort -u > /tmp/kitpkgs
    bash -ic 'kit uninstall' > /tmp/pout 2>&1 </dev/null; rc=$?
    chk "exit 1: kept what $dep needs" [ $rc = 1 ]
    [ $rc = 1 ] || cat /tmp/pout
    chk "gdb, there before the kit, still installed" on_path gdb
    chk "clangd gone" not on_path clangd
    chk "$dep still works" sh -c "$dep --version >/dev/null"
    still=$(pkgs | grep -xF -f /tmp/kitpkgs)
    reported() {
        [ -n "$still" ] && [ "$(sed -n \
            's/.*kept \(.*\): still needed by other packages$/\1/p' \
            /tmp/pout | tr ' ' '\n' | sort)" = "$still" ]
    }
    chk "the kit's packages $dep needs are kept and reported" reported
    [ $PM = pacman ] || chk "the kept ones are not left selected for purge" \
        not sh -c 'dpkg --get-selections | grep -qw -e deinstall -e purge'
    # the kept ones are dependencies now: they go with $dep
    if [ $PM = apt ]; then
        apt-get purge -y -qq --autoremove \
            -o APT::AutoRemove::RecommendsImportant=false \
            -o APT::AutoRemove::SuggestsImportant=false $dep >/dev/null 2>&1
    else
        pacman -Rs --noconfirm $dep >/dev/null
    fi
    same_pkgs() { pkgs | diff /tmp/pkgs0 - > /tmp/pkgdiff \
                      || { cat /tmp/pkgdiff; false; }; }
    chk "with $dep removed, the package list is the one before setup" \
        same_pkgs
    echo "== packages: $pass passed, $fail failed"

    as_student KIT_PACKAGES=no bash "$0" && [ $fail = 0 ]
    exit
fi

K=$HOME/.local/share/epita-kit
LINE="[ -r '$K/bashrc' ] && export KIT_DIR='$K' && . '$K/bashrc' # epita-kit"
setup() { sh /kit/setup.sh > /tmp/out 2>&1; }
# $HOME as uninstall must leave it: every path, type, link target, size
# and mode, plus every regular file's checksum. The runtime files the
# tools create while used are the user's and are left out, with ~/.cache
# that holds their caches (and a directory's size, which counts them).
RUNTIME='^\./\(\.bash_history\|\.gdb_history\|\.viminfo\|\.vim/undo'
RUNTIME="$RUNTIME"'\|\.cache/tlrc\|\.cache/starship\)\( \|/\|$\)'
snapshot() {
    (cd ~ && { find . -type d -printf '%p %y %m\n' \
                   -o -printf '%p %y %l %s %m\n'
               find . -type f -exec sha256sum {} + \
                   | sed 's/^\(\S*\)  \(.*\)$/\2 \1/'
             } | grep -v -e "$RUNTIME" -e '^\./\.cache d ' | sort)
}
# the tools in use, as a user would: the shell with the kit, vim
use_env() {
    bash -ic 'kit; cc99 --version' >/dev/null 2>&1 </dev/null
    timeout 60 vim -Nu ~/.vimrc -c 'qa!' >/dev/null 2>&1 </dev/null
}
# the user edits ~/.bashrc around the kit line after install
edit_bashrc() {
    sed -i -e '/# epita-kit$/i # above' -e '/# epita-kit$/a # below' ~/.bashrc
}
# after uninstall: ~/.bashrc is the original plus the user's two lines;
# then it is put back to the original, for the snapshot comparison
bashrc_kept_user_lines() {
    local want; want=$(cat /tmp/bashrc0; printf '# above\n# below\n')
    [ "$(cat ~/.bashrc)" = "$want" ] && cat /tmp/bashrc0 > ~/.bashrc
}
same_home() {
    snapshot > /tmp/snap1
    diff /tmp/snap0 /tmp/snap1 >/tmp/snapdiff || { cat /tmp/snapdiff; false; }
}

echo "== standalone [$(. /etc/os-release && echo "$ID $VERSION_ID")]"
echo "-- A1 first install"
echo mine > ~/.vimrc
# dotfiles kept as symlinks (stow), one of them dangling
mkdir ~/dotfiles && echo 'set editing-mode vi' > ~/dotfiles/inputrc
ln -s ~/dotfiles/inputrc ~/.inputrc && ln -s ~/dotfiles/gdbinit ~/.gdbinit
cp ~/.bashrc /tmp/bashrc0
snapshot > /tmp/snap0
setup; rc=$?
chk "exit 0" [ $rc = 0 ]
[ $rc = 0 ] || cat /tmp/out
chk "no ~/afs created" [ ! -e ~/afs -a ! -L ~/afs ]
chk "kit home has the configs" [ -f "$K/vimrc" ]
chk "~/.vimrc linked into the kit home" [ "$(readlink ~/.vimrc)" = "$K/vimrc" ]
chk "own ~/.vimrc kept as backup" \
    grep -qx mine ~/.vimrc.local-backup
chk "own ~/.inputrc link kept as backup" \
    [ "$(readlink ~/.inputrc.local-backup)" = ~/dotfiles/inputrc ]
chk "own dangling ~/.gdbinit link kept as backup" \
    [ "$(readlink ~/.gdbinit.local-backup)" = ~/dotfiles/gdbinit ]
# each binary is the machine's own build (the ELF machine of /bin/sh):
# Docker Desktop runs foreign ones through binfmt emulation, so a
# working --version alone would pass an x86_64 build on aarch64
native_bin() {
    [ "$(od -An -j18 -N2 -tx1 "$K/bin/$1")" = \
        "$(od -An -j18 -N2 -tx1 /bin/sh)" ] \
        && "$K/bin/$1" --version >/dev/null \
        || grep -q "$1: no build for $(uname -m), skipped" /tmp/out
}
for b in starship fzf rg fd bat tldr; do
    chk "$b runs, built for $(uname -m) (or has no build for it)" \
        native_bin "$b"
done
chk "~/.bashrc still a regular file" [ -f ~/.bashrc -a ! -L ~/.bashrc ]
chk "~/.bashrc ends with the kit line" \
    [ "$(tail -n 1 ~/.bashrc)" = "$LINE" ]
J=$K/.journal
TAB=$(printf '\t')
chk "journal: ~/.vimrc link with its backup" \
    grep -qxF "link$TAB$HOME/.vimrc$TAB$K/vimrc$TAB$HOME/.vimrc.local-backup" \
    "$J"
chk "journal: one line entry, for ~/.bashrc" \
    [ "$(grep "^line$TAB" "$J" 2>/dev/null | cut -f 2)" = "$HOME/.bashrc" ]
chk "journal: the line entry is the kit line" \
    grep -qxF "line$TAB$HOME/.bashrc$TAB$LINE" "$J"
cp "$J" /tmp/journal1 2>/dev/null

echo "-- A2 bashrc finds the kit home"
out=$(bash -ic 'echo $KIT_DIR; command -v rg; kit | head -1' \
    2>/dev/null </dev/null)
chk "KIT_DIR exported ($(sed -n 1p <<<"$out"))" \
    [ "$(sed -n 1p <<<"$out")" = "$K" ]
chk "extras on PATH ($(sed -n 2p <<<"$out"))" \
    [ "$(sed -n 2p <<<"$out")" = "$K/bin/rg" ]
chk "kit cheatsheet found" grep -q 'EPITA PIE kit' <<<"$(sed -n 3p <<<"$out")"

echo "-- A3 rerun converges"
setup; rc=$?
chk "exit 0" [ $rc = 0 ]
chk "kit line appended once" [ "$(grep -c '# epita-kit$' ~/.bashrc)" = 1 ]
same_journal() {
    [ -s "$J" ] && [ "$(cksum < "$J")" = "$(cksum < /tmp/journal1)" ]
}
chk "journal unchanged (converged run writes nothing)" same_journal
chk "still no ~/afs" [ ! -e ~/afs -a ! -L ~/afs ]

echo "-- A4 ~/afs an empty directory (sshfs mount down), own dotfiles"
# the AFS layout, never standalone; uninstall puts the files back
H=$(mktemp -d); mkdir "$H/afs"
echo '# mine' > "$H/.bashrc"; echo mine > "$H/.vimrc"
HOME=$H sh /kit/setup.sh > /tmp/out4 2>&1; rc=$?
chk "exit 0" [ $rc = 0 ]
[ $rc = 0 ] || cat /tmp/out4
chk "not standalone" not grep -q 'no AFS: installing' /tmp/out4
chk "~/.vimrc linked into ~/afs/.confs" \
    [ "$(readlink "$H/.vimrc")" = "$H/afs/.confs/vimrc" ]
chk "no standalone kit home" [ ! -e "$H/.local/share/epita-kit" ]
HOME=$H sh "$H/afs/.confs/uninstall.sh" > /tmp/out4 2>&1; rc=$?
chk "uninstall exit 0" [ $rc = 0 ]
[ $rc = 0 ] || cat /tmp/out4
chk "~/.vimrc and ~/.bashrc are the user's own again" sh -c \
    '[ ! -L "$1/.vimrc" ] && [ "$(cat "$1/.vimrc")" = mine ] &&
     [ ! -L "$1/.bashrc" ] && [ "$(cat "$1/.bashrc")" = "# mine" ]' _ "$H"
chk "no backup left behind" \
    [ ! -e "$H/.vimrc.local-backup" -a ! -e "$H/.bashrc.local-backup" ]

uninstall_checks() {
    chk "exit 0" [ "$1" = 0 ]
    [ "$1" = 0 ] || cat /tmp/out
    chk "~/.vimrc is the user's own again" \
        sh -c '[ ! -L ~/.vimrc ] && [ "$(cat ~/.vimrc)" = mine ]'
    chk "no backup left behind" [ ! -e ~/.vimrc.local-backup ]
    chk "~/.inputrc, ~/.gdbinit: the user's links again" \
        [ "$(readlink ~/.inputrc)" = ~/dotfiles/inputrc \
          -a "$(readlink ~/.gdbinit)" = ~/dotfiles/gdbinit ]
    chk "~/.bashrc: the original plus the user's two lines" \
        bashrc_kept_user_lines
    chk "kit home gone" [ ! -e "$K" ]
    chk "\$HOME identical to before the install" same_home
}

echo "-- A5 uninstall after two setups (A1, A3), with the env used"
use_env; edit_bashrc
bash -ic 'kit uninstall' > /tmp/out 2>&1 </dev/null
uninstall_checks $?

echo "-- A6 setup once, use, uninstall"
setup; rc=$?
chk "setup exit 0" [ $rc = 0 ]
use_env; edit_bashrc
bash -ic 'kit uninstall' > /tmp/out 2>&1 </dev/null
uninstall_checks $?

echo "-- A7 a link the user repointed is kept; undo history survives"
# ~/.vim is the user's dangling link: it comes back, the history moves
# to ~/.vim-undo. Uninstalled right away: the plugin clones setup
# started still run.
ln -s ~/dotfiles/vim ~/.vim
setup
echo x > /tmp/f.c
timeout 60 vim -Nu ~/.vimrc -es -c 'normal Ay' -c wq /tmp/f.c \
    >/dev/null 2>&1 </dev/null
chk "vim wrote undo history (into the kit home)" \
    [ -n "$(ls -A "$K/vim/undo" 2>/dev/null)" ]
ln -sfn /etc/hostname ~/.inputrc
bash -ic 'kit uninstall; echo "rc=$?"; kit uninstall; echo "rc=$?"' \
    > /tmp/out 2>&1 </dev/null
chk "exit 1" grep -qx 'rc=1' /tmp/out
chk "repointed link reported" \
    grep -q "\[-\] kept $HOME/.inputrc: " /tmp/out
chk "repointed link kept" [ "$(readlink ~/.inputrc)" = /etc/hostname ]
chk "the rest uninstalled" sh -c '[ ! -e "$1" ] && [ ! -L ~/.vimrc ]' _ "$K"
sleep 30
chk "plugin clones still running do not bring the kit home back" \
    [ ! -e "$K" ]
chk "~/.vim the user's link again" [ "$(readlink ~/.vim)" = ~/dotfiles/vim ]
chk "undo history kept in ~/.vim-undo" \
    [ -n "$(ls -A ~/.vim-undo 2>/dev/null)" ]

echo "-- A8 uninstall again: nothing to do"
chk "second kit uninstall: exit 0" grep -qx 'rc=0' /tmp/out
chk "second kit uninstall: says so" grep -q 'nothing to uninstall' /tmp/out
KIT_DIR=$K sh /kit/uninstall.sh > /tmp/out 2>&1; rc=$?
chk "uninstall.sh with no journal: exit 0" [ $rc = 0 ]
chk "uninstall.sh with no journal: says so" \
    grep -q 'nothing to uninstall' /tmp/out

echo "== $pass passed, $fail failed"
[ $fail = 0 ]

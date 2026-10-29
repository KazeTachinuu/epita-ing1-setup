#!/bin/bash
# install.sh as PAM runs it at a PIE login, as the unprivileged student.
# /kit: the kit under test; /cri: the CRI skeleton (epita-default-confs).
SH=${SH:-dash}
case $SH in busybox-ash) RUN="busybox ash" ;; *) RUN=$SH ;; esac
pass=0 fail=0
ok()  { pass=$((pass+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
ko()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
chk() { local m=$1; shift; if "$@"; then ok "$m"; else ko "$m"; fi; }
W=$(mktemp -d)
PINS="lsp:c741b2f1afb42b9f267824dac4049674908f4a41
auto-pairs:94d0577fea5c0b3dc71dbd2df7667dcffb830b3b
vim-vsnip:9bcfabea653abdcdac584283b5097c3f8760abaa
vim-clang-format:6b791825ff478061ad1c57b21bb1ed5a5fd0eb29
friendly-snippets:b2ea5c41a150ba72fb656eedb4ed0a86d138d945"

# a fresh PIE login: the CRI skeleton with the kit's files over it (what
# setup.sh does) in the cell, ~/afs a symlink into /afs as PAM makes it.
# Prints the home; its AFS is $home/afs.
mkafs() {
    local a=/afs/cri.epita.fr/user/$1 h=$W/home-$1
    rm -rf "$a" "$h"; mkdir -p "$a/.confs" "$h"
    cp -r /cri/. "$a/.confs/"
    for f in install.sh cheatsheet clang-format starship.toml vimrc \
        vimrc.exam bashrc gdbinit inputrc tmux.conf alacritty.toml; do
        cp "/kit/$f" "$a/.confs/$f"
    done
    mkdir -p "$a/.confs/mozilla/firefox/abc.default"
    echo history > "$a/.confs/mozilla/firefox/abc.default/places.sqlite"
    echo key > "$a/.confs/ssh/id_ed25519"
    ln -s "$a" "$h/afs"
    echo "$h"
}
inst() { HOME=$1 AFS_DIR=$2 $RUN "$2/.confs/install.sh"; }
# plugins are fetched in the background: wait until every pin is in place
plugins_at_pins() {
    local p h
    for p in $PINS; do
        h=$(git -C "$1/${p%%:*}" rev-parse -q --verify HEAD 2>/dev/null)
        [ "$h" = "${p#*:}" ] || return 1
    done
}
wait_plugins() {
    for _ in $(seq 120); do plugins_at_pins "$1" && return 0; sleep 1; done
    return 1
}
snap() { (cd "$1" && find . -printf '%p %y %l %s\n' | sort); }

echo "== install.sh [sh=$SH]"

echo "-- T1 fresh PIE login: superset of the CRI dot_list"
H=$(mkafs t1); A=$H/afs
inst "$H" "$A"; rc=$?
chk "exit 0" [ $rc = 0 ]
for f in bashrc config emacs gitconfig gitignore jnewsrc mozilla msmtprc \
    muttrc signature slrnrc ssh vim vimrc Xdefaults; do
    chk "~/.$f -> AFS (CRI)" [ "$(readlink "$H/.$f")" = "$A/.confs/$f" ]
done
for f in clang-format gdbinit inputrc; do
    chk "~/.$f -> AFS (kit)" [ "$(readlink "$H/.$f")" = "$A/.confs/$f" ]
done
chk "firefox history reachable" \
    [ "$(cat "$H/.mozilla/firefox/abc.default/places.sqlite" 2>/dev/null)" = history ]
chk "ssh key reachable" [ -f "$H/.ssh/id_ed25519" ]
chk "tmux.conf lands in AFS config" [ -L "$A/.confs/config/tmux/tmux.conf" ]
chk "starship.toml reachable" [ -r "$H/.config/starship.toml" ]
chk "no backups on an empty home" [ -z "$(ls -a "$H" | grep local-backup)" ]
chk "plugins reach their pins" wait_plugins "$A/.confs/vim/pack/kit/start"
chk "no temp dir in start/" \
    [ -z "$(ls -a "$A/.confs/vim/pack/kit/start" | grep '^\.new')" ]
q='echo exists(":LspGotoDefinition") exists(":VsnipOpen") exists(":ClangFormat")'
out=$(HOME=$H vim -Nu "$H/.vimrc" -i NONE -es \
    -c "redir! > /dev/stdout | $q | redir END" -c 'qa!' 2>&1 | tr -d '\r\n ')
chk "vim loads lsp/vsnip/clang-format ($out)" [ "$out" = 222 ]

echo "-- T2 second login is a no-op"
before=$(snap "$H"); inst "$H" "$A"; sleep 2; after=$(snap "$H")
chk "home unchanged" [ "$before" = "$after" ]
# the journal is standalone-only: a PIE login never writes one
chk "no journal in the AFS cell or home" \
    [ -z "$(find /afs/cri.epita.fr "$H" -name .journal 2>/dev/null)" ]

echo "-- T3 home with real files: moved aside, never lost"
H=$(mkafs t3); A=$H/afs; mkdir -p "$H/.mozilla" "$H/.ssh"
echo mine > "$H/.mozilla/own"; echo mine > "$H/.bashrc"
echo older > "$H/.bashrc.local-backup"
inst "$H" "$A"
chk "~/.mozilla linked" [ "$(readlink "$H/.mozilla")" = "$A/.confs/mozilla" ]
chk "own ~/.mozilla kept" \
    [ "$(cat "$H/.mozilla.local-backup/own" 2>/dev/null)" = mine ]
chk "older backup not overwritten" [ "$(cat "$H/.bashrc.local-backup")" = older ]
chk "new backup kept too" grep -qx mine $H/.bashrc.local-backup*
chk "AFS files untouched" \
    [ -f "$A/.confs/mozilla/firefox/abc.default/places.sqlite" ]

echo "-- T4 unmovable dir: never linked inside it"
H=$(mkafs t4); A=$H/afs; mkdir -p "$H/.mozilla"; chmod 555 "$H"
inst "$H" "$A" 2>/dev/null
chmod 755 "$H"
chk "no link created inside ~/.mozilla" [ ! -e "$H/.mozilla/mozilla" ]

echo "-- T5 clone cut short by the logout pkill recovers"
H=$(mkafs t5); A=$H/afs; P=$A/.confs/vim/pack/kit/start
mkdir -p "$P"; git init -q "$P/lsp"          # what a killed clone leaves
inst "$H" "$A"
chk "empty lsp repo refetched" wait_plugins "$P"

echo "-- T6 plugin at an old commit is moved to its pin"
git -C "$P/auto-pairs" -c user.name=t -c user.email=t \
    commit -q --allow-empty -m drift
inst "$H" "$A"
chk "drifted auto-pairs back at pin" wait_plugins "$P"

echo "-- T7 real kill mid-clone, then next login"
H=$(mkafs t7); A=$H/afs; P=$A/.confs/vim/pack/kit/start
inst "$H" "$A"; sleep 1.5
pkill -9 -u "$(id -u)" -f "$A/.confs/install.sh"; pkill -9 -u "$(id -u)" git
sleep 1
chk "nothing half-cloned in start/" sh -c '
    for d in "$1"/*; do [ -e "$d" ] || continue
        git -C "$d" rev-parse -q --verify HEAD >/dev/null || exit 1; done' _ "$P"
inst "$H" "$A"
chk "next login completes the set" wait_plugins "$P"

echo "-- T8 stale temp dirs from killed sessions are swept"
mkdir -p "$P/../.new.lsp.999"; touch -d '-2 hours' "$P/../.new.lsp.999"
mkdir -p "$P/../.new.lsp.998"                      # a concurrent login's
inst "$H" "$A"; sleep 3
chk "old temp swept" [ ! -e "$P/../.new.lsp.999" ]
chk "fresh temp left alone" [ -e "$P/../.new.lsp.998" ]

echo "-- T9 login never waits on the network"
H=$(mkafs t9); A=$H/afs
t0=$(date +%s%N); inst "$H" "$A"; rc=$?; t1=$(date +%s%N)
ms=$(( (t1 - t0) / 1000000 ))
chk "exit 0" [ $rc = 0 ]
chk "returns in < 1s (${ms}ms)" [ $ms -lt 1000 ]

echo "-- T10 no AFS confs: exit 0, nothing dangling"
H=$W/h10; mkdir -p "$H" "$W/emptyafs"
HOME=$H AFS_DIR=$W/emptyafs $RUN /kit/install.sh; rc=$?
chk "exit 0" [ $rc = 0 ]
chk "no dangling links" [ -z "$(find "$H" -xtype l)" ]

echo "-- T11 not the PIE (local ~/afs dir, persistent home): own ~/.ssh kept"
H=$W/h11; mkdir -p "$H/.ssh" "$H/afs/.confs/ssh"; echo mine > "$H/.ssh/id"
cp /kit/install.sh /kit/vimrc "$H/afs/.confs/"
HOME=$H AFS_DIR=$H/afs $RUN "$H/afs/.confs/install.sh"
chk "~/.ssh left alone" sh -c '[ ! -L "$1/.ssh" ] && [ -f "$1/.ssh/id" ]' _ "$H"
chk "kit links still made" [ "$(readlink "$H/.vimrc")" = "$H/afs/.confs/vimrc" ]

echo "-- T12 uninstall on the PIE layout: the CRI files back, user data kept"
# setup.sh's first run over the CRI skeleton: the files it overwrites are
# copied to .confs.backup, its extras land next to the configs
H=$(mkafs t12); A=$H/afs; C=$A/.confs
mkdir -p "$A/.confs.backup" "$C/bin" "$C/pylib"
cp /cri/bashrc /cri/vimrc /cri/install.sh "$A/.confs.backup/"
touch "$C/.kit" "$C/gef.py" "$C/bin/rg"
inst "$H" "$A"
wait_plugins "$C/vim/pack/kit/start"
HOME=$H AFS_DIR=$A KIT_DIR=$C $RUN /kit/uninstall.sh > "$W/out12" 2>&1; rc=$?
chk "exit 0" [ $rc = 0 ]
[ $rc = 0 ] || cat "$W/out12"
for f in bashrc vimrc install.sh; do
    chk "$f is the CRI one again" cmp -s "/cri/$f" "$C/$f"
done
chk "firefox profile untouched" \
    [ "$(cat "$C/mozilla/firefox/abc.default/places.sqlite")" = history ]
chk "ssh key untouched" [ "$(cat "$C/ssh/id_ed25519")" = key ]
for f in bin pylib .kit gef.py gdbinit cheatsheet vim/pack/kit; do
    chk "no $f" [ ! -e "$C/$f" ]
done
chk "CRI vim dir kept" [ -d "$C/vim/bundle" ]
chk "no .confs.backup" [ ! -e "$A/.confs.backup" ]
chk "~/.vimrc gone or the CRI vimrc" sh -c '
    [ ! -e "$1" ] && [ ! -L "$1" ] || [ "$(readlink "$1")" = "$2" ]' \
    _ "$H/.vimrc" "$C/vimrc"
chk "no dangling links" [ -z "$(find "$H" "$C" -xtype l)" ]

echo "== $pass passed, $fail failed"
[ $fail = 0 ]

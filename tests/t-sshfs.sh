#!/bin/bash
# From home: ~/afs is a real sshfs mount (fuse.sshfs) and home persists.
# Runs as root in a --privileged container; the checks run as student.
set -u
/usr/sbin/sshd
mkdir -p /srv/afs/.confs && cp -r /cri/. /srv/afs/.confs/
for f in install.sh cheatsheet clang-format starship.toml vimrc vimrc.exam \
    bashrc gdbinit inputrc tmux.conf alacritty.toml; do
    cp "/kit/$f" /srv/afs/.confs/
done
mkdir -p /srv/afs/.confs/mozilla/firefox
# the gate side is another user, as the real EPITA gate is another machine
# (the same user on localhost would read ~/.bashrc through the mount)
useradd -m gate; chown -R gate /srv/afs; chmod -R a+rwX /srv/afs
su student -c 'mkdir -p ~/.sshk && ssh-keygen -q -t ed25519 -N "" -f ~/.sshk/k'
cp /home/student/.sshk/k.pub /etc/ssh/ak/gate

exec su student -c 'bash -s' <<'EOS'
pass=0 fail=0
ok()  { pass=$((pass+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
ko()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
chk() { local m=$1; shift; if "$@"; then ok "$m"; else ko "$m"; fi; }
H=$HOME A=$HOME/afs
mnt() {
    mkdir -p "$A"
    timeout 20 sshfs -o IdentityFile=$HOME/.sshk/k,StrictHostKeyChecking=no \
        gate@localhost:/srv/afs "$A"
}
umnt() { fusermount3 -u "$A" 2>/dev/null || fusermount -u "$A"; }
# install.sh, then wait for its background plugin clones (they write under
# ~/afs or ~/.vim, which the next step removes or remounts)
inst() {
    timeout 60 env AFS_DIR=$A sh "$A/.confs/install.sh"
    for _ in $(seq 180); do
        pgrep -u "$(id -u)" -f 'confs/install.sh|git' >/dev/null || break
        sleep 1
    done
}
# what setup.sh does when sshfs is down: ~/afs becomes a plain local dir
localafs() { mkdir -p "$A/.confs"; cp -r /srv/afs/.confs/. "$A/.confs/"; }

echo "== sshfs"
mnt
fst=$(df -PT "$A" | awk 'NR==2{print $2}')
chk "mounted as fuse.sshfs ($fst)" [ "$fst" = fuse.sshfs ]

echo "-- U1 student's own ~/.vim, from home"
mkdir -p "$H/.vim/colors"; echo mine > "$H/.vim/colors/own.vim"
inst
chk "own file still there" [ -f "$H/.vim/colors/own.vim" ]
chk "own ~/.vim not marked as the kit's" [ ! -e "$H/.vim/.kit-created" ]
chk "vimrc linked over sshfs" [ "$(readlink "$H/.vimrc")" = "$A/.confs/vimrc" ]
chk "mozilla not linked from home" [ ! -L "$H/.mozilla" ]
chk "config not linked from home" [ ! -L "$H/.config" ]
chk "ssh untouched" [ ! -L "$H/.ssh" ]

echo "-- U2 sshfs down, kit update falls back to a local ~/afs"
umnt; localafs; inst
chk "~/.ssh not linked off the PIE" [ ! -L "$H/.ssh" ]
chk "own vim file not deleted" sh -c '[ -f "$1/.vim/colors/own.vim" ] ||
    [ -f "$1/.vim.local-backup/colors/own.vim" ]' _ "$H"
rm -rf "$A" "$H/.vim" "$H/.vim.local-backup"* "$H/.vimrc"*

echo "-- U3 no ~/.vim: the kit's own local copy, dropped back on campus"
mnt; inst
chk "kit-created marker set" [ -e "$H/.vim/.kit-created" ]
umnt; localafs; inst
chk "~/.vim is the AFS link again" [ "$(readlink "$H/.vim")" = "$A/.confs/vim" ]
chk "no stray backup of the kit copy" [ ! -e "$H/.vim.local-backup" ]
rm -rf "$A" "$H/.vim" "$H/.vim.local-backup"*

echo "-- U4 dir marked .kit-copy by an older kit: moved, not deleted"
mkdir -p "$H/.vim"; echo mine > "$H/.vim/own"; touch "$H/.vim/.kit-copy"
localafs; inst
chk "own file survives" sh -c '[ -f "$1/.vim/own" ] ||
    [ -f "$1/.vim.local-backup/own" ]' _ "$H"

echo "== $pass passed, $fail failed"
[ $fail = 0 ]
EOS

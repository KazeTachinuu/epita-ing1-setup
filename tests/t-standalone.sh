#!/bin/bash
# setup.sh on a plain distro (no AFS, no PIE): the standalone layout under
# ~/.local/share/epita-kit. Starts as root in a stock image (IMAGE= in
# run.sh), installs what a fresh machine lacks, then re-runs itself as an
# unprivileged user for the checks. Configs are served from /kit
# (PIE_BASE), standing in for raw.githubusercontent.com at the PIN.
if [ "$(id -u)" = 0 ]; then
    if command -v apt-get >/dev/null; then
        apt-get update -qq && DEBIAN_FRONTEND=noninteractive \
            apt-get install -y -qq --no-install-recommends curl \
            ca-certificates python3 git sudo vim >/dev/null
    elif command -v pacman >/dev/null; then
        pacman -Sy --noconfirm --needed curl ca-certificates python git \
            sudo vim >/dev/null
    fi || { echo "cannot install test prerequisites"; exit 1; }
    useradd -m -s /bin/bash student || exit 1
    (cd /kit && exec python3 -m http.server 8000 >/dev/null 2>&1) &
    sleep 1
    exec sudo -u student -H env PIE_BASE=http://localhost:8000 \
        KIT_PACKAGES=no bash "$0"
fi

pass=0 fail=0
ok()  { pass=$((pass+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
ko()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
chk() { local m=$1; shift; if "$@"; then ok "$m"; else ko "$m"; fi; }
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

echo "-- A4 PIE home copied elsewhere: dangling ~/afs into /afs"
# AFS not mounted, AFS_DIR unset: the link becomes a local ~/afs (the AFS
# layout), as before standalone mode existed; never a pie-mode abort
H=$(mktemp -d)
ln -s /afs/cri.epita.fr/user/s/student "$H/afs"
HOME=$H sh /kit/setup.sh > /tmp/out4 2>&1; rc=$?
chk "exit 0" [ $rc = 0 ]
[ $rc = 0 ] || cat /tmp/out4
chk "~/afs now a local directory" [ -d "$H/afs" -a ! -L "$H/afs" ]
chk "configs in ~/afs/.confs" [ -f "$H/afs/.confs/vimrc" ]
chk "~/.vimrc linked into ~/afs/.confs" \
    [ "$(readlink "$H/.vimrc")" = "$H/afs/.confs/vimrc" ]
chk "no standalone kit home" [ ! -e "$H/.local/share/epita-kit" ]

uninstall_checks() {
    chk "exit 0" [ "$1" = 0 ]
    [ "$1" = 0 ] || cat /tmp/out
    chk "~/.vimrc is the user's own again" \
        sh -c '[ ! -L ~/.vimrc ] && [ "$(cat ~/.vimrc)" = mine ]'
    chk "no backup left behind" [ ! -e ~/.vimrc.local-backup ]
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
# uninstalled right away: the plugin clones setup started still run
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
chk "undo history kept in ~/.vim/undo" \
    [ -n "$(ls -A ~/.vim/undo 2>/dev/null)" ]

echo "-- A8 uninstall again: nothing to do"
chk "second kit uninstall: exit 0" grep -qx 'rc=0' /tmp/out
chk "second kit uninstall: says so" grep -q 'nothing to uninstall' /tmp/out
KIT_DIR=$K sh /kit/uninstall.sh > /tmp/out 2>&1; rc=$?
chk "uninstall.sh with no journal: exit 0" [ $rc = 0 ]
chk "uninstall.sh with no journal: says so" \
    grep -q 'nothing to uninstall' /tmp/out

echo "== $pass passed, $fail failed"
[ $fail = 0 ]

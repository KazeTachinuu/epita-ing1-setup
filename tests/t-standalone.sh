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
            ca-certificates python3 git sudo >/dev/null
    elif command -v pacman >/dev/null; then
        pacman -Sy --noconfirm --needed curl ca-certificates python git \
            sudo >/dev/null
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

echo "== standalone [$(. /etc/os-release && echo "$ID $VERSION_ID")]"
echo "-- A1 first install"
echo mine > ~/.vimrc
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
chk "still no ~/afs" [ ! -e ~/afs -a ! -L ~/afs ]

echo "== $pass passed, $fail failed"
[ $fail = 0 ]

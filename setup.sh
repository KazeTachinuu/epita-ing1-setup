#!/bin/sh
# EPITA PIE setup, one line:
#
#   curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/master/setup.sh | sh
#
# Everything installs to ~/afs/.confs; the PIE reapplies it at every
# login on every machine. Idempotent, safe to re-run.
#
#   PIE_MINIMAL=1  configs only, skip the downloads (starship, fzf, GEF)
#   PIE_BASE=url   fetch configs from another location (testing)
#   AFS_DIR=path   AFS user dir (default ~/afs; the same variable the
#                  PIE's PAM hook passes to install.sh at every login)
set -eu

# configs come from a pinned commit, not a mutable branch: the bytes you
# get are exactly the bytes reviewed at release time
PIN=50b1020bbd9f1b084f62f7542aba0ad63477ceb1
BASE="${PIE_BASE:-https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/$PIN}"
AFS="${AFS_DIR:-$HOME/afs}"
DOT="$AFS/.confs"
FILES="install.sh clang-format starship.toml vimrc vimrc.exam bashrc
       gdbinit inputrc tmux.conf alacritty.toml"

STARSHIP_V=1.26.0
STARSHIP_SHA=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3
FZF_V=0.74.2
FZF_SHA=b3648f48675612b69ee35371cf6dc99ca96d767e89b912d079080916ac8ba8bd
FZF_KB_SHA=89103adb2e29816b0ed8f36814ce4c95945a5f1c7dcd3b0620d2973ea2dbd6ea
RG_V=15.2.0
RG_SHA=33e15bcf1624b25cdd2a55813a47a2f95dbe126268203e76aa6a585d1e7b149c
FD_V=10.4.2
FD_SHA=e3257d48e29a6be965187dbd24ce9af564e0fe67b3e73c9bdcd180f4ec11bdde
GEF_V=2026.01
GEF_SHA=04cdfe961f1e9151933d32cf6b548d9e6a76a1aef8b27c020c575b8d4264ed20

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    G='\033[1;32m' Y='\033[1;33m' B='\033[1;34m' D='\033[2m' N='\033[0m'
else
    G= Y= B= D= N=
fi
say()      { printf "${G}[+]${N} %s\n" "$1"; }
skip()     { printf "${D}[=]${N} ${D}%s${N}\n" "$1"; }
warn()     { printf "${Y}[-]${N} %s\n" "$1"; }
extras()   { [ "${PIE_MINIMAL:-0}" != 1 ]; }
verified() { printf '%s  %s\n' "$2" "$1" | sha256sum -c - >/dev/null 2>&1; }

printf "${B}==>${N} EPITA PIE starter kit (pinned @ %.7s)\n" "$PIN"

# no AFS here (VM, standalone machine): a dangling ~/afs symlink becomes
# a real local directory so the same paths work everywhere
if [ -L "$AFS" ] && [ ! -e "$AFS" ]; then
    say "no AFS mounted: using a local $AFS directory instead"
    rm "$AFS"
fi
mkdir -p "$DOT"
cd "$DOT"

# every download lands under a temporary name and is moved into place
# only when complete (and verified); the trap sweeps interrupted leftovers
trap 'rm -rf "$DOT"/.new.*' EXIT

set -- $FILES
say "configs: fetching $# files -> $DOT"
for f in $FILES; do
    curl -fsSL "$BASE/$f" -o ".new.$f"
    mv ".new.$f" "$f"
done
chmod +x install.sh

# link configs before the optional downloads: a network failure below
# must never leave configs fetched but not installed
say "configs: linked into \$HOME (install.sh; vim plugins clone in background)"

AFS_DIR="$AFS" ./install.sh

# the extras below are loaded by inert hooks (bashrc, gdbinit) only when
# present; each one skips on failure, the kit works without any of them

# fetch_bin <bin> <version> <url> <sha> <path-in-tar>: pinned static
# binary, checksum-verified, atomically placed in bin/
fetch_bin() {
    extras || return 0
    if [ -x "bin/$1" ]; then
        skip "$1: already installed ($("bin/$1" --version 2>/dev/null | head -1 || echo unknown))"
        return 0
    fi
    say "$1: fetching $2 (checksum-verified)"
    if curl -fsSL -o ".new.$1.tgz" "$3" && verified ".new.$1.tgz" "$4" \
        && mkdir -p ".new.$1" bin && tar xzf ".new.$1.tgz" -C ".new.$1"; then
        mv ".new.$1/$5" "bin/$1"
    else
        warn "$1: fetch or checksum failed, skipped"
    fi
}

fetch_bin starship "v$STARSHIP_V" \
    "https://github.com/starship/starship/releases/download/v$STARSHIP_V/starship-x86_64-unknown-linux-musl.tar.gz" \
    "$STARSHIP_SHA" starship
fetch_bin fzf "v$FZF_V" \
    "https://github.com/junegunn/fzf/releases/download/v$FZF_V/fzf-$FZF_V-linux_amd64.tar.gz" \
    "$FZF_SHA" fzf
fetch_bin rg "v$RG_V (ripgrep)" \
    "https://github.com/BurntSushi/ripgrep/releases/download/$RG_V/ripgrep-$RG_V-x86_64-unknown-linux-musl.tar.gz" \
    "$RG_SHA" "ripgrep-$RG_V-x86_64-unknown-linux-musl/rg"
fetch_bin fd "v$FD_V" \
    "https://github.com/sharkdp/fd/releases/download/v$FD_V/fd-v$FD_V-x86_64-unknown-linux-musl.tar.gz" \
    "$FD_SHA" "fd-v$FD_V-x86_64-unknown-linux-musl/fd"

# fzf's bash key bindings (fuzzy Ctrl-R history, Ctrl-T files)
if extras && [ -x bin/fzf ] && [ ! -r fzf-key-bindings.bash ]; then
    if curl -fsSL -o .new.fzf-kb.bash \
        "https://raw.githubusercontent.com/junegunn/fzf/v$FZF_V/shell/key-bindings.bash" \
        && verified .new.fzf-kb.bash "$FZF_KB_SHA"; then
        mv .new.fzf-kb.bash fzf-key-bindings.bash
    else
        warn "fzf key bindings: fetch or checksum failed, skipped"
    fi
fi

# GEF: pinned release, checksum-verified
if ! extras; then :
elif [ -e gef.py ]; then
    skip "GEF: already installed"
else
    say "GEF: fetching $GEF_V (checksum-verified)"
    if curl -fsSL -o .new.gef.py "https://raw.githubusercontent.com/hugsy/gef/$GEF_V/gef.py" \
        && verified .new.gef.py "$GEF_SHA"; then
        mv .new.gef.py gef.py
    else
        warn "GEF: fetch or checksum failed, skipped"
    fi
fi

printf "${G}==>${N} done. Log out and back in, or run: exec bash\n"

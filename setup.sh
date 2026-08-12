#!/bin/sh
# EPITA PIE setup, one line:
#
#   curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/master/setup.sh | sh
#
# Everything installs to ~/afs/.confs; the PIE reapplies it at every
# login on every machine. Idempotent, safe to re-run.
#
#   PIE_MINIMAL=1  configs only, skip the downloads (starship, ble.sh, GEF)
#   PIE_BASE=url   fetch configs from another location (testing)
set -eu

# configs come from a pinned commit, not a mutable branch: the bytes you
# get are exactly the bytes reviewed at release time
PIN=cc1eabaf0b7f4d43eeac57c8f7460a5c07bf4701
BASE="${PIE_BASE:-https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/$PIN}"
DOT="$HOME/afs/.confs"
FILES="install.sh clang-format starship.toml vimrc vimrc.exam bashrc
       gdbinit inputrc tmux.conf alacritty.toml"

STARSHIP_V=1.26.0
STARSHIP_SHA=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3
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
if [ -L "$HOME/afs" ] && [ ! -e "$HOME/afs" ]; then
    say "no AFS mounted: using a local ~/afs directory instead"
    rm "$HOME/afs"
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

AFS_DIR="$HOME/afs" ./install.sh

# the extras below are loaded by inert hooks (bashrc, gdbinit) only when
# present; each one skips on failure, the kit works without any of them

# starship: pinned static binary, checksum-verified
if ! extras; then :
elif [ -x bin/starship ]; then
    skip "starship: already installed ($(bin/starship --version 2>/dev/null | head -1 || echo unknown))"
else
    say "starship: fetching v$STARSHIP_V (checksum-verified)"
    if curl -fsSL -o .new.starship.tgz \
        "https://github.com/starship/starship/releases/download/v$STARSHIP_V/starship-x86_64-unknown-linux-musl.tar.gz" \
        && verified .new.starship.tgz "$STARSHIP_SHA" \
        && mkdir -p .new.bin && tar xzf .new.starship.tgz -C .new.bin; then
        mkdir -p bin && mv .new.bin/starship bin/starship
    else
        warn "starship: fetch or checksum failed, skipped"
    fi
fi

# ble.sh: nightly is the only build for bash 5.3 and ships no stable
# checksum upstream, so this one cannot be pinned
if ! extras; then :
elif [ -r blesh/ble.sh ]; then
    skip "ble.sh: already installed"
else
    say "ble.sh: fetching nightly (unpinned: no stable checksum upstream)"
    if mkdir -p .new.blesh && curl -fsSL \
        https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
        | tar xJ -C .new.blesh --strip-components=1; then
        rm -rf blesh && mv .new.blesh blesh
    else
        warn "ble.sh: fetch failed, skipped"
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

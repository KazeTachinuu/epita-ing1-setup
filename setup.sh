#!/bin/sh
# EPITA PIE full setup in one line:
#
#   curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/config/master/pie/setup.sh | sh
#
# Installs everything into ~/afs/.confs (vim + LSP, bash, gdb, tmux,
# readline, alacritty, checksum-verified starship); the PIE then reapplies
# it at every login on every campus machine. Safe to re-run any time.
#
#   PIE_MINIMAL=1  skip the extras (starship)
#   PIE_BASE=url   fetch from another location (testing)

set -e
# configs are fetched from a pinned commit, not a mutable branch: the
# bytes you get are exactly the bytes reviewed at release time
PIN=6e1680b2804e9afb6bcee886dfbea143ef0b0fbf
BASE="${PIE_BASE:-https://raw.githubusercontent.com/KazeTachinuu/config/$PIN/pie}"
DOT="$HOME/afs/.confs"

say() { printf '[+] %s\n' "$1"; }

# no AFS here (VM, exam-like machine): a dangling ~/afs symlink becomes a
# real local directory so the same paths work everywhere
if [ -L "$HOME/afs" ] && [ ! -e "$HOME/afs" ]; then
    say "no AFS mounted: using a local ~/afs directory instead"
    rm "$HOME/afs"
fi
mkdir -p "$DOT"
cd "$DOT"

say "fetching configs -> $DOT"
for f in install.sh vimrc vimrc.exam bashrc gdbinit inputrc tmux.conf alacritty.toml; do
    curl -fsSL "$BASE/$f" -o "$f"
done
chmod +x install.sh

# starship: pinned release, checksum-verified, skipped (not fatal) on mismatch
STARSHIP_V=1.26.0
STARSHIP_SHA=b7c232b0e8249d8e55a40beb79c5c43a7d370f3f9408bd215deb0170daeaadf3
if [ "${PIE_MINIMAL:-0}" != 1 ] && [ ! -x bin/starship ]; then
    say "fetching starship v$STARSHIP_V (static binary, verified)"
    curl -fsSL "https://github.com/starship/starship/releases/download/v$STARSHIP_V/starship-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/starship.tgz
    if printf '%s  /tmp/starship.tgz\n' "$STARSHIP_SHA" | sha256sum -c - >/dev/null 2>&1; then
        mkdir -p bin && tar xzf /tmp/starship.tgz -C bin
    else
        printf '[-] starship checksum mismatch, skipping (kit works without it)\n'
    fi
    rm -f /tmp/starship.tgz
fi

say "running install.sh (links configs, clones vim plugins in background)"
AFS_DIR="$HOME/afs" ./install.sh

say "done. Log out and back in, or run: exec bash"

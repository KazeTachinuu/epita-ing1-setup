#!/bin/sh
# EPITA PIE full setup in one line:
#
#   curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/config/master/pie/setup.sh | sh
#
# Installs everything into ~/afs/.confs (vim + LSP, bash, gdb, tmux,
# readline, alacritty, starship, ble.sh); the PIE then reapplies it at
# every login on every campus machine. Safe to re-run any time.
#
#   PIE_MINIMAL=1  skip the extras (starship, ble.sh)
#   PIE_BASE=url   fetch from another location (testing)

set -e
BASE="${PIE_BASE:-https://raw.githubusercontent.com/KazeTachinuu/config/master/pie}"
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

if [ "${PIE_MINIMAL:-0}" != 1 ]; then
    if [ ! -x bin/starship ]; then
        say "fetching starship (static binary)"
        mkdir -p bin
        curl -fsSL https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz \
            | tar xz -C bin
    fi
    if [ ! -r blesh/ble.sh ]; then
        say "fetching ble.sh (bash autosuggestions + syntax highlighting)"
        curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz \
            | tar xJ -C .
        rm -rf blesh && mv ble-nightly blesh
    fi
fi

say "running install.sh (links configs, clones vim plugins in background)"
AFS_DIR="$HOME/afs" ./install.sh

say "done. Log out and back in, or run: exec bash"

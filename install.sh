#!/bin/sh
# EPITA PIE bootstrap.
# Run by PAM at every session open (see nixpie modules/config/users-groups.nix):
# the PIE executes ~/afs/.confs/install.sh with AFS_DIR=$HOME/afs at each login.
# Must therefore be: idempotent, instant when converged, and never fail the login.

DOT="${AFS_DIR:-$HOME/afs}/.confs"

# link <name>: symlink ~/.<name> -> .confs/<name>, converging in zero work when
# already correct. A pre-existing real file is kept once as *.local-backup.
link() {
    src="$DOT/$1" dst="$HOME/.$1"
    [ -e "$src" ] || return 0
    [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return 0
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.local-backup" 2>/dev/null
    fi
    ln -sfn "$src" "$dst"
}

link vimrc
link bashrc
link gitconfig
link clang-format
link gdbinit

exit 0

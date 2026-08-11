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
link inputrc

# tmux reads ~/.config/tmux/tmux.conf; link() only handles ~/.<name>
mkdir -p "$HOME/.config/tmux" 2>/dev/null
[ -e "$DOT/tmux.conf" ] && ln -sfn "$DOT/tmux.conf" "$HOME/.config/tmux/tmux.conf"

# Optional normal-day extras (opt in: touch $DOT/nix-extras).
# Backgrounded and silent: must never delay or fail a login.
if [ -e "$DOT/nix-extras" ] && command -v nix >/dev/null 2>&1; then
    [ -n "${NIX_SSL_CERT_FILE:-}" ] || export NIX_SSL_CERT_FILE=$(echo /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)
    nix --extra-experimental-features 'nix-command flakes' \
        profile add nixpkgs#fzf nixpkgs#bash-completion >/dev/null 2>&1 &
fi

exit 0

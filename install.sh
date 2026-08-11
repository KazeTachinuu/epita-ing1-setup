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

# Plugin layer: ~/.vim lives on AFS; one plugin, native packages, no manager.
mkdir -p "$DOT/vim/pack/kit/start"
link vim

# One-time plugin fetches, pinned to exact commits and verified after
# checkout (removed on any mismatch: no unpinned code ever persists).
# Backgrounded and silent: a login must never wait on the network.
if command -v git >/dev/null 2>&1; then
    (
        export GIT_SSL_CAINFO="${GIT_SSL_CAINFO:-$(echo /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)}"
        for entry in \
            "yegappan/lsp aac0b4671f8868fb40619c6eb54ed254fdb69dc2" \
            "LunarWatcher/auto-pairs 94d0577fea5c0b3dc71dbd2df7667dcffb830b3b" \
            "hrsh7th/vim-vsnip 9bcfabea653abdcdac584283b5097c3f8760abaa" \
            "rhysd/vim-clang-format 6b791825ff478061ad1c57b21bb1ed5a5fd0eb29"
        do
            repo=${entry% *}; pin=${entry#* }
            d="$DOT/vim/pack/kit/start/${repo##*/}"
            [ -d "$d" ] && continue
            git init -q "$d" &&
                git -C "$d" fetch -q --depth 1 "https://github.com/$repo" "$pin" &&
                git -C "$d" checkout -q FETCH_HEAD &&
                [ "$(git -C "$d" rev-parse HEAD)" = "$pin" ] ||
                rm -rf "$d"
        done
    ) >/dev/null 2>&1 &
fi

# XDG-path configs; link() only handles ~/.<name>
mkdir -p "$HOME/.config/tmux" "$HOME/.config/alacritty" 2>/dev/null
[ -e "$DOT/tmux.conf" ] && ln -sfn "$DOT/tmux.conf" "$HOME/.config/tmux/tmux.conf"
[ -e "$DOT/alacritty.toml" ] && ln -sfn "$DOT/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

# Optional normal-day extras (opt in: touch $DOT/nix-extras).
# Backgrounded and silent: must never delay or fail a login.
if [ -e "$DOT/nix-extras" ] && command -v nix >/dev/null 2>&1; then
    [ -n "${NIX_SSL_CERT_FILE:-}" ] || export NIX_SSL_CERT_FILE=$(echo /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)
    nix --extra-experimental-features 'nix-command flakes' \
        profile add nixpkgs#fzf nixpkgs#bash-completion >/dev/null 2>&1 &
fi

exit 0

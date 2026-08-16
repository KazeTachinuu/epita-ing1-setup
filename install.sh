#!/bin/sh
# EPITA PIE bootstrap.
# Run by PAM at every session open (see nixpie modules/config/users-groups.nix):
# the PIE executes ~/afs/.confs/install.sh with AFS_DIR=$HOME/afs at each login.
# Must therefore be: idempotent, instant when converged, and never fail the login.

DOT="${AFS_DIR:-$HOME/afs}/.confs"

# link <name> [dst]: symlink dst (default ~/.<name>) -> .confs/<name>,
# converging in zero work when already correct. A pre-existing real file
# is kept once as *.local-backup.
link() {
    src="$DOT/$1" dst="${2:-$HOME/.$1}"
    [ -e "$src" ] || return 0
    [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return 0
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.local-backup" 2>/dev/null
    fi
    ln -sfn "$src" "$dst"
}

link vimrc
link bashrc
link gitconfig    # not shipped; linked if the student keeps one on AFS (CRI convention)
link clang-format
link gdbinit
link inputrc

# Plugin layer: ~/.vim lives on AFS; one plugin, native packages, no manager.
mkdir -p "$DOT/vim/pack/kit/start"
# Over sshfs, vim's ~150 startup opens are WAN round-trips: copy ~/.vim
# locally instead of linking (home is disposable). The .kit-copy sentinel
# (plugin dir mtime) keeps converged runs to a single stat.
vim_copy() {
    stamp=$(stat -c %Y "$DOT/vim/pack/kit/start" 2>/dev/null || echo none)
    [ "$(cat "$HOME/.vim/.kit-copy" 2>/dev/null)" = "$stamp" ] && return 0
    cp -ru "$DOT/vim/." "$HOME/.vim/" 2>/dev/null
    echo "$stamp" > "$HOME/.vim/.kit-copy"
}
if [ "$(df -PT "$DOT" 2>/dev/null | awk 'NR==2 {print $2}')" = "fuse.sshfs" ]; then
    [ -L "$HOME/.vim" ] && rm -f "$HOME/.vim"      # replace a campus symlink
    mkdir -p "$HOME/.vim"
    vim_copy || true
else
    # back on campus: drop a marked home-copy, restore the canonical symlink
    [ -e "$HOME/.vim/.kit-copy" ] && rm -rf "$HOME/.vim"
    link vim
fi

# One-time plugin fetches, pinned to exact commits and verified after
# checkout (removed on any mismatch: no unpinned code ever persists).
# Backgrounded and silent: a login must never wait on the network.
if command -v git >/dev/null 2>&1; then
    (
        # the PIE image ships CA certs only in the nix store; on machines
        # with a normal cert setup the glob misses and git's default works
        ca=$(echo /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)
        [ -e "$ca" ] && export GIT_SSL_CAINFO="${GIT_SSL_CAINFO:-$ca}"
        for entry in \
            "yegappan/lsp aac0b4671f8868fb40619c6eb54ed254fdb69dc2" \
            "LunarWatcher/auto-pairs 94d0577fea5c0b3dc71dbd2df7667dcffb830b3b" \
            "hrsh7th/vim-vsnip 9bcfabea653abdcdac584283b5097c3f8760abaa" \
            "rafamadriz/friendly-snippets 6cd7280adead7f586db6fccbd15d2cac7e2188b9" \
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
        # copy mode: fold fresh clones into the local ~/.vim now
        [ -e "$HOME/.vim/.kit-copy" ] && vim_copy
    ) >/dev/null 2>&1 &
fi

# XDG-path configs, same backup semantics
mkdir -p "$HOME/.config/tmux" "$HOME/.config/alacritty" 2>/dev/null
link tmux.conf "$HOME/.config/tmux/tmux.conf"
link alacritty.toml "$HOME/.config/alacritty/alacritty.toml"
link starship.toml "$HOME/.config/starship.toml"

# Optional normal-day extras (opt in: touch $DOT/nix-extras).
# Backgrounded and silent: must never delay or fail a login.
if [ -e "$DOT/nix-extras" ] && command -v nix >/dev/null 2>&1; then
    [ -n "${NIX_SSL_CERT_FILE:-}" ] || export NIX_SSL_CERT_FILE=$(echo /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)
    nix --extra-experimental-features 'nix-command flakes' \
        profile add nixpkgs#fzf nixpkgs#bash-completion >/dev/null 2>&1 &
fi

exit 0

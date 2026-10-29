#!/bin/sh
# EPITA PIE bootstrap.
# Run by PAM at every session open (see nixpie modules/config/users-groups.nix):
# the PIE executes ~/afs/.confs/install.sh with AFS_DIR=$HOME/afs at each
# login. Must therefore be idempotent, instant when converged, and never
# fail the login.
# KIT_MODE, KIT_DIR: passed by setup.sh (pie|sshfs|afs|standalone, the kit
# home); PAM passes neither, so a login is pie on $AFS_DIR/.confs.

KIT_MODE="${KIT_MODE:-pie}"
DOT="${KIT_DIR:-${AFS_DIR:-$HOME/afs}/.confs}"

# journal <type> <field>...: record one change made outside the kit home
# as a TAB-separated line in $KIT_JOURNAL, for uninstall.sh to undo.
# Set by setup.sh in standalone only: a PIE login never writes one.
journal() {
    [ -n "${KIT_JOURNAL:-}" ] || return 0
    (IFS=$(printf '\t'); printf '%s\n' "$*") >> "$KIT_JOURNAL"
}

# link <name> [dst]: symlink dst (default ~/.<name>) -> .confs/<name>,
# no-op when already correct. A pre-existing real file or dir is moved
# aside, never deleted: to *.local-backup, or a dated name when that one
# is taken. If it cannot be moved, nothing is linked over it.
link() {
    src="$DOT/$1" dst="${2:-$HOME/.$1}"
    [ -e "$src" ] || return 0
    [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return 0
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        bak="$dst.local-backup"
        if [ -e "$bak" ] || [ -L "$bak" ]; then
            bak="$bak.$(date +%Y%m%d-%H%M%S)"
        fi
        mv "$dst" "$bak" 2>/dev/null || return 0
    else
        bak=
    fi
    ln -sfn "$src" "$dst" && journal link "$dst" "$src" "$bak"
}

link vimrc
# standalone: ~/.bashrc is the user's own (distro default or theirs) and
# stays theirs; the kit appends one marked line sourcing its bashrc, once
if [ "$KIT_MODE" = standalone ]; then
    rc="$HOME/.bashrc"
    if ! grep -q '# epita-kit$' "$rc" 2>/dev/null; then
        # a last line without its newline would swallow ours
        [ -s "$rc" ] && [ -n "$(tail -c 1 "$rc")" ] && echo >> "$rc"
        line="[ -r '$DOT/bashrc' ] && export KIT_DIR='$DOT' &&"
        line="$line . '$DOT/bashrc' # epita-kit"
        printf '%s\n' "$line" >> "$rc" && journal line "$rc" "$line"
    fi
else
    link bashrc
fi
link gitconfig    # not shipped; linked if kept on AFS (CRI convention)
link clang-format
link gdbinit
link inputrc

# Plugin layer: ~/.vim on AFS, native packages, no manager. Over sshfs
# (from-home mount) every vim file access is a WAN round-trip, so there
# ~/.vim is a plain local dir and plugins clone straight from GitHub into
# it (pinned, fast); home is disposable, AFS keeps the campus set.
fstype=$(df -PT "$DOT" 2>/dev/null | awk 'NR==2 {print $2}')
if [ "$fstype" = "fuse.sshfs" ]; then
    [ -L "$HOME/.vim" ] && rm -f "$HOME/.vim"
    # mark the dir as ours only when we create it: a ~/.vim that already
    # exists is the user's own and must never be deleted below
    if [ ! -e "$HOME/.vim" ]; then
        mkdir -p "$HOME/.vim" && touch "$HOME/.vim/.kit-created"
    fi
    PLUG="$HOME/.vim/pack/kit/start"
    mkdir -p "$PLUG"
else
    # back on campus: drop the local dir only if the kit created it (older
    # kits used a .kit-copy marker, also put in users' own dirs: those are
    # no longer trusted and link moves the dir aside instead), then
    # restore the canonical symlink
    if [ ! -L "$HOME/.vim" ] && [ -e "$HOME/.vim/.kit-created" ]; then
        rm -rf "$HOME/.vim"
    fi
    PLUG="$DOT/vim/pack/kit/start"
    mkdir -p "$PLUG"
    link vim
    # the CRI default install.sh (github.com/epita/epita-default-confs),
    # which this one replaces, also linked these from AFS: the Firefox
    # profile, ssh keys, ~/.config... Dropping them wiped them at each
    # login. Real PIE only, where PAM makes ~/afs a symlink into /afs
    # (nixpie users-groups.nix): anywhere else home persists and these
    # are the user's own.
    case "$(readlink "${AFS_DIR:-$HOME/afs}")" in /afs/*)
        for f in mozilla ssh config emacs gitignore Xdefaults msmtprc \
            muttrc signature slrnrc jnewsrc; do
            link "$f"
        done ;;
    esac
fi

# Plugin fetches, pinned to exact commits: a plugin is in place only when
# its checkout is at its pin. Anything else (a clone cut short by the
# logout pkill, an older pin) is fetched again into a temp dir outside
# start/ (vim would load a half-cloned dir) and swapped in once verified.
# Backgrounded and silent: a login must never wait on the network.
if command -v git >/dev/null 2>&1; then
    (
        # the PIE image ships CA certs only in the nix store; on machines
        # with a normal cert setup the glob misses and git's default works
        set -- /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt
        [ -e "$1" ] && export GIT_SSL_CAINFO="${GIT_SSL_CAINFO:-$1}"
        # sweep temp dirs left by killed sessions (not a concurrent login's)
        find "$PLUG/.." -maxdepth 1 -name '.new.*' -mmin +30 \
            -exec rm -rf {} + 2>/dev/null
        for entry in \
        "yegappan/lsp aac0b4671f8868fb40619c6eb54ed254fdb69dc2" \
        "LunarWatcher/auto-pairs 94d0577fea5c0b3dc71dbd2df7667dcffb830b3b" \
        "hrsh7th/vim-vsnip 9bcfabea653abdcdac584283b5097c3f8760abaa" \
        "rhysd/vim-clang-format 6b791825ff478061ad1c57b21bb1ed5a5fd0eb29" \
        "rafamadriz/friendly-snippets 6cd7280adead7f586db6fccbd15d2cac7e2188b9"
        do
            repo=${entry% *}; pin=${entry#* }
            d="$PLUG/${repo##*/}"
            head=$(git -C "$d" rev-parse -q --verify HEAD 2>/dev/null)
            [ "$head" = "$pin" ] && continue
            t="$PLUG/../.new.${repo##*/}.$$"
            rm -rf "$t"
            # a stalled transfer aborts instead of hanging until logout
            if git init -q "$t" &&
                git -C "$t" -c http.lowSpeedLimit=1000 \
                    -c http.lowSpeedTime=30 fetch -q --depth 1 \
                    "https://github.com/$repo" "$pin" &&
                git -C "$t" checkout -q FETCH_HEAD &&
                [ "$(git -C "$t" rev-parse HEAD)" = "$pin" ]
            then
                rm -rf "$d" && mv "$t" "$d"
            fi
            rm -rf "$t"
        done
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
    if [ -z "${NIX_SSL_CERT_FILE:-}" ]; then
        set -- /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt
        [ -e "$1" ] && export NIX_SSL_CERT_FILE="$1"
    fi
    nix --extra-experimental-features 'nix-command flakes' \
        profile add nixpkgs#fzf nixpkgs#bash-completion >/dev/null 2>&1 &
fi

exit 0

#!/bin/sh
# EPITA PIE setup, one line:
#
#   curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/master/setup.sh | sh
#
# On the PIE everything installs to ~/afs/.confs and the PIE reapplies it
# at every login on every machine; anywhere else (no AFS) it installs to
# ~/.local/share/epita-kit, linked once. Idempotent, safe to re-run.
#
#   PIE_MINIMAL=1  configs only, skip all optional downloads
#   PIE_BASE=url   fetch configs from another location (testing)
#   AFS_DIR=path   AFS user dir (default ~/afs; the same variable the
#                  PIE's PAM hook passes to install.sh at every login)
set -eu

# configs come from a pinned commit, not a mutable branch: the bytes you
# get are exactly the bytes reviewed at release time
PIN=f596d064e941f7817954527f98eab78145e500ab
RAWGH=https://raw.githubusercontent.com
GH=https://github.com
BASE="${PIE_BASE:-$RAWGH/KazeTachinuu/epita-ing1-setup/$PIN}"
AFS="${AFS_DIR:-$HOME/afs}"
FILES="install.sh cheatsheet clang-format starship.toml vimrc vimrc.exam bashrc
       gdbinit inputrc tmux.conf alacritty.toml packages.sh uninstall.sh"

STARSHIP_V=1.27.0
STARSHIP_SHA_X86_64=10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89
STARSHIP_SHA_AARCH64=341f5cbf24699fa0b27ec88965ad25f862ea09e15d35a543fd6ffdff1d2aa00d
FZF_V=0.74.5
FZF_SHA_X86_64=d47d7f882972c7d674dbbba998ffa4116e68379616ffac7695d0671e9a722c5f
FZF_SHA_AARCH64=cf058001da21724a469b714a29cf4aab9cbe860d218a0d6c1b5b661efad7784c
FZF_KB_SHA=89103adb2e29816b0ed8f36814ce4c95945a5f1c7dcd3b0620d2973ea2dbd6ea
RG_V=15.2.0
RG_SHA_X86_64=33e15bcf1624b25cdd2a55813a47a2f95dbe126268203e76aa6a585d1e7b149c
RG_SHA_AARCH64=800b1e7206afe799dfb5a6901f23147cfaabe0e52210538100f61e86e1740915
FD_V=10.5.0
FD_SHA_X86_64=761c72dc8e120d85b22292063be8a796e2eeb20eb3e4f38b8fa2343ccf3514a7
FD_SHA_AARCH64=d76c4317f7d5dba69f8a2a15856c90c777e7f0dd4e85f0de8c76de6992c374d4
BAT_V=0.26.1
BAT_SHA_X86_64=0dcd8ac79732c0d5b136f11f4ee00e581440e16a44eab5b3105b611bbf2cf191
BAT_SHA_AARCH64=6369242c584065f195fb20cb36fbd7cb63ae690605bbe89868a7596b596c2c23
TLRC_V=1.13.1
TLRC_SHA_X86_64=e63b80e180b956ae2114c39d7fb10e607ffaa46b6d8c370d90868389a228584d
TLRC_SHA_AARCH64=f2e52e567d22301ea926095eef97daefe2a60c2bea6222ecc27136a9c338e9f7
GEF_V=2026.01
GEF_SHA=04cdfe961f1e9151933d32cf6b548d9e6a76a1aef8b27c020c575b8d4264ed20
ECS_V=3.5.0
IGN_PIN=abc54db9cc3f6baf61b6ae7bfc6e2cc9858f5612
IGN_SHA=9a43816e88a690af3c9b9507d60b782bb79ff2d6bfc67d1c1347df84de4ccd2f

# this machine's builds; another architecture has none: its tools are
# skipped, the rest of the kit works without them
ARCH=$(uname -m)
FZF_ARCH= STARSHIP_SHA= FZF_SHA= RG_SHA= FD_SHA= BAT_SHA= TLRC_SHA=
case $ARCH in
x86_64)
    FZF_ARCH=amd64
    STARSHIP_SHA=$STARSHIP_SHA_X86_64 FZF_SHA=$FZF_SHA_X86_64
    RG_SHA=$RG_SHA_X86_64 FD_SHA=$FD_SHA_X86_64
    BAT_SHA=$BAT_SHA_X86_64 TLRC_SHA=$TLRC_SHA_X86_64 ;;
aarch64)
    FZF_ARCH=arm64
    STARSHIP_SHA=$STARSHIP_SHA_AARCH64 FZF_SHA=$FZF_SHA_AARCH64
    RG_SHA=$RG_SHA_AARCH64 FD_SHA=$FD_SHA_AARCH64
    BAT_SHA=$BAT_SHA_AARCH64 TLRC_SHA=$TLRC_SHA_AARCH64 ;;
esac

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
fstype()   { df -PT "$1" 2>/dev/null | awk 'NR==2 {print $2}'; }

# detect_mode: where the kit lives, first match wins.
#   pie         ~/afs is PAM's symlink into the AFS cell
#   sshfs       the PIE AFS mounted from home over sshfs
#   afs         an AFS layout without the PIE: AFS_DIR set, or a ~/afs
#               directory (a VM, or an sshfs mount point while it is down)
#   standalone  anything else: a machine with no AFS at all
detect_mode() {
    case "$(readlink "$AFS")" in
    /afs/*) [ -d "$AFS" ] && { echo pie; return; } ;;
    esac
    if [ "$(fstype "$AFS")" = fuse.sshfs ]; then
        echo sshfs
    elif [ -n "${AFS_DIR:-}" ] || [ -d "$AFS" ]; then
        echo afs
    else
        echo standalone
    fi
}

# every download aborts on a stalled connection instead of hanging
CURL_OPTS="--connect-timeout 5 --speed-limit 1 --speed-time 30 --retry 1"
# on a terminal, downloads show curl's progress bar (stderr); quiet otherwise
CURL="curl -fsSL $CURL_OPTS"
[ -t 2 ] && CURL="curl -f#L $CURL_OPTS"

# everything imperative lives in main, called on the last line: a truncated
# curl | sh download defines a broken function and executes nothing
main() {

printf "${B}==>${N} EPITA PIE starter kit (pinned @ %.7s)\n" "$PIN"

# curl | sudo sh would put the home part in root's home: the kit is run
# as the user, and asks for sudo itself for the system packages
if [ "$(id -u)" = 0 ] && [ -n "${SUDO_USER:-}" ]; then
    warn "run it as yourself: the kit asks for sudo when it needs it"
    exit 1
fi

mode=$(detect_mode)
if [ "$mode" = standalone ]; then
    KIT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/epita-kit"
    # what install.sh and packages.sh change outside the kit home is
    # recorded here, for kit uninstall to undo
    export KIT_JOURNAL="$KIT_DIR/.journal"
    say "no AFS: installing to $KIT_DIR"
else
    KIT_DIR="$AFS/.confs"
fi
DOT="$KIT_DIR"

# standalone: the kit home's parents that do not exist yet (a fresh
# account has no ~/.local) are journaled as created, so uninstall leaves
# no empty directories behind
if [ "$mode" = standalone ] && [ ! -e "$DOT" ]; then
    new= d=$(dirname "$DOT")
    while [ ! -e "$d" ]; do
        new="$d
$new"
        d=$(dirname "$d")
    done
    mkdir -p "$DOT"
    printf '%s' "$new" | while IFS= read -r d; do
        printf 'dir\t%s\n' "$d"
    done >> "$KIT_JOURNAL"
fi
mkdir -p "$DOT"
cd "$DOT"

# first run over a .confs this kit did not create: back up only the files
# we are about to overwrite. A full cp -a of the tree would crawl over
# sshfs (vim-plugin .git repos, pylib: thousands of tiny files); their
# other files are left untouched in place. Standalone has no prior .confs:
# the files it replaces in $HOME are moved aside by install.sh's link.
if [ "$mode" != standalone ] && [ ! -e .kit ] \
    && [ ! -e "$AFS/.confs.backup" ]; then
    for f in $FILES; do
        [ -e "$f" ] || continue
        mkdir -p "$AFS/.confs.backup"
        cp -a "$f" "$AFS/.confs.backup/"
    done
    [ -e "$AFS/.confs.backup" ] &&
        say "existing configs found: kept a copy in .confs.backup"
fi
touch .kit

# every download lands under a temporary name and is moved into place
# only when complete (and verified); the trap sweeps interrupted leftovers
trap 'rm -rf "$DOT"/.new.*' EXIT

# the .kit stamp already at this PIN means the configs are these bytes
if [ "$(cat .kit 2>/dev/null)" = "$PIN" ]; then
    skip "configs: already at $(printf %.7s "$PIN")"
else
    set -- $FILES
    say "configs: fetching $# files -> $DOT"
    i=0
    for f in $FILES; do
        i=$((i + 1))
        [ -t 1 ] && printf "\r    ${D}%2d/%d %s${N}\033[K" "$i" "$#" "$f" \
            || true
        curl -fsSL $CURL_OPTS "$BASE/$f" -o ".new.$f"
        mv ".new.$f" "$f"
    done
    [ -t 1 ] && printf '\r\033[K' || true
    chmod +x install.sh
    printf '%s\n' "$PIN" > .kit    # version stamp, read by `kit status`
fi

# standalone: the system packages first, install.sh's plugin clones need
# git (the PIE and the AFS layout keep theirs)
[ "$mode" != standalone ] || sh packages.sh install

# install configs before the optional downloads: a network failure below
# must never leave configs fetched but not installed
say "configs: installing into \$HOME (vim plugins clone in background)..."
KIT_MODE="$mode" KIT_DIR="$KIT_DIR" AFS_DIR="$AFS" ./install.sh
say "configs: installed"

# extras are machine-generated: over sshfs they live locally (WAN reads
# at every prompt/run hurt); on campus they stay on AFS, and
# standalone keeps them in the kit home
if [ "$mode" = sshfs ]; then
    EXTRAS="$HOME/.pie"
    say "extras: sshfs AFS detected, installing to $EXTRAS (local)"
else
    EXTRAS="$DOT"
fi
mkdir -p "$EXTRAS"
cd "$EXTRAS"
trap 'rm -rf "$DOT"/.new.* "$EXTRAS"/.new.*' EXIT

# the extras below are loaded by inert hooks (bashrc, gdbinit) only when
# present; each one skips on failure, the kit works without any of them

# fetch_bin <bin> <version> <url> <sha> <path-in-tar>: pinned static
# binary, checksum-verified, atomically placed in bin/; skipped only
# while the installed --version still matches the pin
fetch_bin() {
    extras || return 0
    [ -n "$4" ] || { warn "$1: no build for $ARCH, skipped"; return 0; }
    ver=${2#v}; ver=${ver%% *}
    if [ -x "bin/$1" ]; then
        v=$("bin/$1" --version 2>/dev/null | head -1 || echo unknown)
        # the pin as a whole version token: 0.26.1 must not match 0.26.10
        case " $v " in *[!0-9.]"$ver"[!0-9.]*)
            skip "$1: already installed ($v)"; return 0 ;;
        esac
        say "$1: updating to $2 (had: $v)"
    else
        say "$1: fetching $2 (checksum-verified)"
    fi
    # every step is checked: under set -e a bare failure (a release whose
    # archive layout changed) would abort all the extras after this one
    rm -rf ".new.$1" ".new.$1.tgz"
    if $CURL -o ".new.$1.tgz" "$3" && verified ".new.$1.tgz" "$4" \
        && mkdir -p ".new.$1" bin && tar xzf ".new.$1.tgz" -C ".new.$1" \
        && [ -f ".new.$1/$5" ] && mv ".new.$1/$5" "bin/$1"; then
        rm -rf ".new.$1" ".new.$1.tgz"
    else
        warn "$1: fetch, checksum or unpack failed, skipped"
    fi
}

# a \ at end of line inside double quotes continues the string: the long
# release URLs below are single tokens split for the 80-column limit
fetch_bin starship "v$STARSHIP_V" \
    "$GH/starship/starship/releases/download/v$STARSHIP_V\
/starship-$ARCH-unknown-linux-musl.tar.gz" \
    "$STARSHIP_SHA" starship
fetch_bin fzf "v$FZF_V" \
    "$GH/junegunn/fzf/releases/download/v$FZF_V\
/fzf-$FZF_V-linux_$FZF_ARCH.tar.gz" \
    "$FZF_SHA" fzf
fetch_bin rg "v$RG_V (ripgrep)" \
    "$GH/BurntSushi/ripgrep/releases/download/$RG_V\
/ripgrep-$RG_V-$ARCH-unknown-linux-musl.tar.gz" \
    "$RG_SHA" "ripgrep-$RG_V-$ARCH-unknown-linux-musl/rg"
fetch_bin fd "v$FD_V" \
    "$GH/sharkdp/fd/releases/download/v$FD_V\
/fd-v$FD_V-$ARCH-unknown-linux-musl.tar.gz" \
    "$FD_SHA" "fd-v$FD_V-$ARCH-unknown-linux-musl/fd"
fetch_bin bat "v$BAT_V" \
    "$GH/sharkdp/bat/releases/download/v$BAT_V\
/bat-v$BAT_V-$ARCH-unknown-linux-musl.tar.gz" \
    "$BAT_SHA" "bat-v$BAT_V-$ARCH-unknown-linux-musl/bat"
fetch_bin tldr "v$TLRC_V (tlrc)" \
    "$GH/tldr-pages/tlrc/releases/download/v$TLRC_V\
/tlrc-v$TLRC_V-$ARCH-unknown-linux-musl.tar.gz" \
    "$TLRC_SHA" tldr

# fzf's bash key bindings (fuzzy Ctrl-R history, Ctrl-T files)
if extras && [ -x bin/fzf ] && ! verified fzf-key-bindings.bash "$FZF_KB_SHA"
then
    if curl -fsSL $CURL_OPTS -o .new.fzf-kb.bash \
        "$RAWGH/junegunn/fzf/v$FZF_V/shell/key-bindings.bash" \
        && verified .new.fzf-kb.bash "$FZF_KB_SHA"; then
        mv .new.fzf-kb.bash fzf-key-bindings.bash
    else
        warn "fzf key bindings: fetch or checksum failed, skipped"
    fi
fi

# GEF: pinned release, checksum-verified
if ! extras; then :
elif verified gef.py "$GEF_SHA"; then
    skip "GEF: already installed ($GEF_V)"
else
    say "GEF: fetching $GEF_V (checksum-verified)"
    if $CURL -o .new.gef.py "$RAWGH/hugsy/gef/$GEF_V/gef.py" \
        && verified .new.gef.py "$GEF_SHA"; then
        mv .new.gef.py gef.py
    else
        warn "GEF: fetch or checksum failed, skipped"
    fi
fi

# epita-coding-style: 54-rule AST linter for the graded style. Python
# package, pinned version; integrity rests on PyPI over TLS (pip
# resolves dependencies, so there is no single artifact to checksum).
if ! extras; then :
elif [ -x bin/coding-style-check ] \
    && [ -d "pylib/epita_coding_style-$ECS_V.dist-info" ]; then
    skip "coding-style-check: already installed ($ECS_V)"
else
    say "coding-style-check: fetching epita-coding-style $ECS_V (PyPI, pinned)"
    set -- /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt
    [ -e "$1" ] && export PIP_CERT="$1" SSL_CERT_FILE="$1"
    if [ -t 2 ]; then pipq=; else pipq=-q; fi
    # no pip cache, no .pyc: both land on AFS, where small writes crawl
    if python3 -m pip install $pipq --no-cache-dir --no-compile \
        --target .new.pylib "epita-coding-style==$ECS_V"; then
        rm -rf pylib && mv .new.pylib pylib && mkdir -p bin
        cat > bin/coding-style-check <<EOF
#!/bin/sh
export PYTHONPATH="$EXTRAS/pylib\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 "$EXTRAS/pylib/bin/epita-coding-style" "\$@"
EOF
        chmod +x bin/coding-style-check
    else
        warn "coding-style-check: pip install failed, skipped"
    fi
fi

# ignore: appends school-provided files from exercise PDFs to .gitignore
# (KazeTachinuu/epita-gitignore, pinned commit, checksum-verified)
if ! extras; then :
elif verified bin/ignore "$IGN_SHA"; then
    skip "ignore: already installed ($(printf %.7s "$IGN_PIN"))"
else
    say "ignore: epita-gitignore @ $(printf %.7s "$IGN_PIN") (verified)"
    if $CURL -o .new.ignore \
        "$RAWGH/KazeTachinuu/epita-gitignore/$IGN_PIN/ignore.sh" \
        && verified .new.ignore "$IGN_SHA"; then
        mkdir -p bin && mv .new.ignore bin/ignore && chmod +x bin/ignore
    else
        warn "ignore: fetch or checksum failed, skipped"
    fi
fi

printf "${G}==>${N} done. Run: ${B}exec bash${N}, then type ${B}kit${N} for the cheatsheet\n"

}
main "$@"

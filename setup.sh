#!/bin/sh
# EPITA PIE setup, one line:
#
#   curl -fsSL https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/master/setup.sh | sh
#
# Everything installs to ~/afs/.confs; the PIE reapplies it at every
# login on every machine. Idempotent, safe to re-run.
#
#   PIE_MINIMAL=1  configs only, skip all optional downloads
#   PIE_BASE=url   fetch configs from another location (testing)
#   AFS_DIR=path   AFS user dir (default ~/afs; the same variable the
#                  PIE's PAM hook passes to install.sh at every login)
set -eu

# configs come from a pinned commit, not a mutable branch: the bytes you
# get are exactly the bytes reviewed at release time
PIN=7ed9ec6f1cc5a70cef7523f8c6443050e359ee51
BASE="${PIE_BASE:-https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup/$PIN}"
AFS="${AFS_DIR:-$HOME/afs}"
DOT="$AFS/.confs"
FILES="install.sh cheatsheet clang-format starship.toml vimrc vimrc.exam bashrc
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
ECS_V=2.0.0
IGN_PIN=cb55b56180dc14e6f95bbad20238d21c933df400
IGN_SHA=cfef81bb8dbb01962d891edd11d4b2efb267c9107ddb887e4b607e092b12b540

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

# on a terminal, downloads show curl's progress bar (stderr); quiet otherwise
if [ -t 2 ]; then CURL="curl -f#L"; else CURL="curl -fsSL"; fi

printf "${B}==>${N} EPITA PIE starter kit (pinned @ %.7s)\n" "$PIN"

# no AFS here (VM, standalone machine): a dangling ~/afs symlink becomes
# a real local directory so the same paths work everywhere
if [ -L "$AFS" ] && [ ! -e "$AFS" ]; then
    say "no AFS mounted: using a local $AFS directory instead"
    rm "$AFS"
fi
mkdir -p "$DOT"
cd "$DOT"

# a pre-existing .confs this kit did not create is copied once to
# .confs.backup before anything gets overwritten
if [ ! -e .kit ] && [ -n "$(ls -A . 2>/dev/null)" ] && [ ! -e "$AFS/.confs.backup" ]; then
    say "existing .confs found: keeping a copy in .confs.backup"
    cp -a "$DOT" "$AFS/.confs.backup"
fi
touch .kit

# every download lands under a temporary name and is moved into place
# only when complete (and verified); the trap sweeps interrupted leftovers
trap 'rm -rf "$DOT"/.new.*' EXIT

set -- $FILES
say "configs: fetching $# files -> $DOT"
i=0
for f in $FILES; do
    i=$((i + 1))
    [ -t 1 ] && printf "\r    ${D}%2d/%d %s${N}\033[K" "$i" "$#" "$f" || true
    curl -fsSL "$BASE/$f" -o ".new.$f"
    mv ".new.$f" "$f"
done
[ -t 1 ] && printf '\r\033[K' || true
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
    if $CURL -o ".new.$1.tgz" "$3" && verified ".new.$1.tgz" "$4" \
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
    if $CURL -o .new.gef.py "https://raw.githubusercontent.com/hugsy/gef/$GEF_V/gef.py" \
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
elif [ -x bin/coding-style-check ]; then
    skip "coding-style-check: already installed"
else
    say "coding-style-check: fetching epita-coding-style $ECS_V (PyPI, pinned)"
    ca=$(echo /nix/store/*nss-cacert*/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)
    if [ -e "$ca" ]; then export PIP_CERT="$ca" SSL_CERT_FILE="$ca"; fi
    if [ -t 2 ]; then pipq=; else pipq=-q; fi
    if python3 -m pip install $pipq --target .new.pylib "epita-coding-style==$ECS_V" 2>/dev/null; then
        rm -rf pylib && mv .new.pylib pylib && mkdir -p bin
        printf '#!/bin/sh\nexport PYTHONPATH="$HOME/afs/.confs/pylib${PYTHONPATH:+:$PYTHONPATH}"\nexec python3 "$HOME/afs/.confs/pylib/bin/coding-style-check" "$@"\n' \
            > bin/coding-style-check
        chmod +x bin/coding-style-check
    else
        warn "coding-style-check: pip install failed, skipped"
    fi
fi

# ignore: appends school-provided files from exercise PDFs to .gitignore
# (KazeTachinuu/epita-gitignore, pinned commit, checksum-verified)
if ! extras; then :
elif [ -x bin/ignore ]; then
    skip "ignore: already installed"
else
    say "ignore: fetching epita-gitignore @ $(printf %.7s "$IGN_PIN") (checksum-verified)"
    if $CURL -o .new.ignore \
        "https://raw.githubusercontent.com/KazeTachinuu/epita-gitignore/$IGN_PIN/ignore.sh" \
        && verified .new.ignore "$IGN_SHA"; then
        mkdir -p bin && mv .new.ignore bin/ignore && chmod +x bin/ignore
    else
        warn "ignore: fetch or checksum failed, skipped"
    fi
fi

printf "${G}==>${N} done. Log out and back in, or run: exec bash\n"

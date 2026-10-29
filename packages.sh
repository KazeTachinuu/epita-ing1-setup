#!/bin/sh
# The system packages the kit relies on (Debian, Ubuntu and Arch
# families; anything else is left alone, silently).
#   sh packages.sh install       run by setup.sh in standalone mode; always
#                                exits 0: prints what it did, or the
#                                command to run
#   sh packages.sh remove <pkg>  run by kit uninstall with the journaled
#                                packages: removes those nothing else needs,
#                                exits 1 when some are kept
#   KIT_PACKAGES=yes|no  go ahead, or don't, without asking
#   otherwise            root goes ahead; a sudo user on a terminal is
#                        asked once; anyone else gets the command to run
#   KIT_JOURNAL          each package installed by this run (named or
#                        pulled in) is recorded as pkg<TAB>apt|pacman<TAB>
#                        name, for kit uninstall
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    G='\033[1;32m' Y='\033[1;33m' D='\033[2m' N='\033[0m'
else
    G= Y= D= N=
fi
say()  { printf "${G}[+]${N} %s\n" "$1"; }
skip() { printf "${D}[=]${N} ${D}%s${N}\n" "$1"; }
warn() { printf "${Y}[-]${N} %s\n" "$1"; }

if command -v apt-get >/dev/null; then
    pm=apt
    want="build-essential gdb valgrind clangd clang-format libcriterion-dev
          lcov vim git curl python3 python3-pip tmux xsel binutils file"
    inst="apt-get install --no-install-recommends" yes=-y
    # installed, whatever is selected for it (hold, or purge after
    # dpkg refused)
    installed() {
        dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' \
            | awk 'substr($1, 2, 1) == "i" { print $2 }' | sort -u
    }
    # dpkg, not apt-get: refuses to remove what another package needs,
    # where apt-get would remove that package too
    mark="apt-mark auto" rm="dpkg --purge" drop="apt-get autoremove --purge"
    # a kit package stays only if something depends on it: one the user's
    # packages merely recommend or suggest (gdb: libc6-dbg, git: patch)
    # was not theirs before the kit either
    orphans() {
        apt-get -s -o APT::AutoRemove::RecommendsImportant=false \
            -o APT::AutoRemove::SuggestsImportant=false autoremove \
            | awk '$1 == "Remv" { print $2 }'
    }
elif command -v pacman >/dev/null; then
    pm=pacman
    want="base-devel gdb valgrind clang criterion lcov vim git curl python
          python-pip tmux xsel binutils file"
    inst="pacman -S --needed" yes=--noconfirm
    installed() { pacman -Qq | sort -u; }
    mark="pacman -D --asdeps" rm="pacman -R --noconfirm"
    drop='pacman -Rs $(pacman -Qdttq)'
    # -tt: likewise, an optional dependency (python: python-pip) can go
    orphans() { pacman -Qdttq; }
else
    exit 0
fi
sudo=
[ "$(id -u)" = 0 ] || sudo=sudo
# as root: sudo, if needed, resets the environment; apt must not stop on
# a configuration question
as_root() { $sudo env DEBIAN_FRONTEND=noninteractive "$@"; }

# allowed <question>: whether to go ahead as root
allowed() {
    case ${KIT_PACKAGES:-} in yes) return 0 ;; no) return 1 ;; esac
    [ -n "$sudo" ] || return 0
    # curl | sh: stdin is the script, the answer comes from the terminal
    command -v sudo >/dev/null && { true </dev/tty; } 2>/dev/null \
        || return 1
    printf '%s [y/N] ' "$1" >/dev/tty
    read -r a </dev/tty
    case $a in [yY]*) ;; *) return 1 ;; esac
}

# remove <pkg>...: marked as dependencies, the package manager says
# which ones nothing else needs any more; those go, the rest is kept
remove() {
    kit=$(printf '%s\n' "$@")
    # the user may have removed some since
    set -- $(installed | grep -xF -e "$kit")
    [ $# -gt 0 ] || return 0
    if ! allowed "remove the $# system packages the kit installed?"; then
        warn "kept $*: not removed without root"
        warn "to remove them: ${sudo:+sudo }$mark $* && ${sudo:+sudo }$drop"
        return 1
    fi
    as_root $mark "$@" >/dev/null
    # pacman lists only the leaves: repeat until none of the kit's is left
    while gone=$(orphans | grep -xF -e "$kit"); do
        as_root $rm $gone || break
    done
    n=$#
    set -- $(installed | grep -xF -e "$kit")
    # dpkg leaves the ones it refused selected for purge
    [ $pm = pacman ] || [ $# = 0 ] \
        || printf '%s install\n' "$@" | as_root dpkg --set-selections
    say "system packages: removed $((n - $#))"
    [ $# = 0 ] || { warn "kept $*: still needed by other packages"; return 1; }
}
[ "${1:-}" != remove ] || { shift; remove "$@"; exit; }

before=$(installed)
missing=$(printf '%s\n' $want | grep -vxF -e "$before")
set -- $missing
if [ $# = 0 ]; then
    skip "system packages: all installed"
else
    warn "system packages missing: $*"
    if ! allowed "install these $# packages?"; then
        warn "to install them: ${sudo:+sudo }$inst $*"
    else
        say "system packages: installing $#"
        if [ $pm = apt ]; then
            as_root apt-get -q update && as_root $inst $yes "$@" \
                || warn "system packages: apt-get failed, see above"
        # a stale database: the fix is a full upgrade, the user's decision
        elif ! as_root $inst $yes "$@"; then
            warn "system packages: not installed"
            warn "run: pacman -Syu, then kit update"
        fi
        [ -z "${KIT_JOURNAL:-}" ] || installed | grep -vxF -e "$before" \
            | while IFS= read -r p; do printf 'pkg\t%s\t%s\n' $pm "$p"; done \
            >> "$KIT_JOURNAL"
    fi
fi

# vim 9 is what the vimrc's LSP client and snippets need
v=$(vim --version 2>/dev/null | awk 'NR == 1 { print int($5) }')
if [ -n "$v" ] && [ "$v" -lt 9 ]; then
    warn "vim $v is older than 9: LSP and snippets are off, the rest works"
fi
exit 0

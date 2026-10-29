#!/bin/sh
# sh packages.sh install: the system packages the kit relies on (Debian,
# Ubuntu and Arch families; anything else is left alone, silently). Run
# by setup.sh in standalone mode. Always exits 0: prints what it did, or
# the command to run.
#   KIT_PACKAGES=yes|no  install, or don't, without asking
#   otherwise            root installs; a sudo user on a terminal is asked
#                        once; anyone else gets the command to run
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
    installed() {
        dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' \
            | awk '$1 == "ii" { print $2 }' | sort -u
    }
elif command -v pacman >/dev/null; then
    pm=pacman
    want="base-devel gdb valgrind clang criterion lcov vim git curl python
          python-pip tmux xsel binutils file"
    inst="pacman -S --needed" yes=--noconfirm
    installed() { pacman -Qq | sort -u; }
else
    exit 0
fi
sudo=
[ "$(id -u)" = 0 ] || sudo=sudo
# as root: sudo, if needed, resets the environment; apt must not stop on
# a configuration question
as_root() { $sudo env DEBIAN_FRONTEND=noninteractive "$@"; }

before=$(installed)
missing=$(printf '%s\n' $want | grep -vxF -e "$before")
set -- $missing
if [ $# = 0 ]; then
    skip "system packages: all installed"
else
    warn "system packages missing: $*"
    go=
    case ${KIT_PACKAGES:-} in
    yes) go=1 ;;
    no) ;;
    *)
        if [ -z "$sudo" ]; then
            go=1
        # curl | sh: stdin is the script, the answer comes from the terminal
        elif command -v sudo >/dev/null && { true </dev/tty; } 2>/dev/null
        then
            printf 'install these %d packages? [y/N] ' $# >/dev/tty
            read -r a </dev/tty
            case $a in [yY]*) go=1 ;; esac
        fi ;;
    esac
    if [ -z "$go" ]; then
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

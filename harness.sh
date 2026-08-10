#!/bin/sh
# pie/harness.sh - PIE lab: run this kit against the real EPITA PIE image.
#
# Faithful to nixpie (modules/config/users-groups.nix): the local home is
# wiped every session, only AFS persists, and PAM runs afs/.confs/install.sh
# (+x required) at each session-open. Every login re-seeds the kit into the
# fake AFS, so the whole dev loop is: edit a file -> ./harness.sh login.
#
# Self-documenting: the help page is generated from the `##` doc comment on
# each cmd_* function. Adding a command means adding one function.
set -eu

# ---- config (every value env-overridable; nothing hardcoded below) ---------
: "${PIE_IMG:=nixos-pie}"                            # docker image to test against
: "${PIE_VOL:=pie-afs}"                              # volume acting as the AFS user dir
: "${PIE_LOGIN:=test.user}"                          # simulated student login
: "${PIE_KIT:=$(dirname "$(realpath "$0")")}"        # config dir seeded into the AFS
: "${PIE_RES:=1600x1000}"                            # gui window size (WxH)
: "${PIE_DISPLAY:=:9}"                               # X display for gui sessions

# real AFS layout: /afs/cri.epita.fr/user/<x>/<xx>/<login>/u
AFS="/afs/cri.epita.fr/user/$(printf %.1s "$PIE_LOGIN")/$(printf %.2s "$PIE_LOGIN")/$PIE_LOGIN/u"

# ---- internals --------------------------------------------------------------
if [ -t 1 ]; then G='\033[32m' R='\033[31m' B='\033[36m' N='\033[0m'; else G= R= B= N=; fi
ok()   { printf "${G}[+]${N} %s\n" "$1"; }
info() { printf "${B}[*]${N} %s\n" "$1"; }
err()  { printf "${R}[-]${N} %s\n" "$1" >&2; }

# session_open: what the PIE does at login, in order:
# runtime dirs (systemd's job on real metal), fresh local home, then the PAM
# hook verbatim from nixpie. Idempotent: every step converges.
session_open() {
    cat <<EOF
mkdir -p /tmp && chmod 1777 /tmp
mkdir -p $AFS/.confs && cp -rpL /kit/. $AFS/.confs/
export HOME=/home/$PIE_LOGIN; mkdir -p \$HOME; cd \$HOME
[ -e \$HOME/afs ] || ln -s $AFS \$HOME/afs
[ -x \$HOME/afs/.confs/install.sh ] && AFS_DIR=\$HOME/afs \$HOME/afs/.confs/install.sh || true
EOF
}

# session <cmd> [docker-args...]: session-open, then <cmd>, in a throwaway
# container. The home dies with it; only the AFS volume persists.
session() {
    _cmd=$1; shift
    docker run --rm -v "$PIE_VOL:$AFS" -v "$PIE_KIT:/kit:ro" \
        -e TERM="${TERM:-xterm}" "$@" "$PIE_IMG" sh -c "$(session_open)
$_cmd"
}

# ---- commands ---------------------------------------------------------------
cmd_login() { ## PIE shell in your terminal, kit applied (default)
    info "PIE session: kit $PIE_KIT -> afs, home wiped on exit"
    session 'exec bash -i' -it
}

cmd_gui() { ## PIE desktop (i3) in a resizable window, kit applied
    pkill -f "Xwayland $PIE_DISPLAY" 2>/dev/null && sleep 1 || true
    # rootful Xwayland: resizing the window resizes the X screen, i3 follows
    Xwayland "$PIE_DISPLAY" -ac -geometry "$PIE_RES" -decorate -host-grab 2>/dev/null &
    trap 'kill $! 2>/dev/null' EXIT
    sleep 1
    info "Ctrl+Shift toggles the keyboard grab (lets Super reach i3)"
    session 'exec i3' \
        -v "/tmp/.X11-unix/X${PIE_DISPLAY#:}:/tmp/.X11-unix/X${PIE_DISPLAY#:}" \
        -e DISPLAY="$PIE_DISPLAY"
}

cmd_exam() { ## config-less machine (approximates exam-pie: same userland, no lockdown)
    info "exam image: stock defaults, nothing persists"
    docker run --rm -it -e TERM="${TERM:-xterm}" "$PIE_IMG" \
        sh -c 'mkdir -p /tmp /root && chmod 1777 /tmp; export HOME=/root; cd; exec bash --norc'
}

cmd_reset() { ## wipe the fake AFS -> factory default
    docker volume rm -f "$PIE_VOL" >/dev/null
    ok "fake AFS wiped -> factory default"
}

cmd_run() { # plumbing for test.bats: login, then run a probe command
    session "$*" -i </dev/null
}

cmd_stock() { # plumbing for test.bats: probe the image with no AFS, no kit
    docker run --rm -i -e HOME=/root -e TERM="${TERM:-xterm}" "$PIE_IMG" \
        sh -c "mkdir -p /tmp /root && chmod 1777 /tmp
$*" </dev/null
}

cmd_help() { ## this page
    printf "${B}PIE lab${N} - test this kit against the real EPITA PIE\n\n"
    printf "${G}usage:${N} %s [command]\n\n" "$0"
    sed -n "s/^cmd_\([a-z]*\)() { ## \(.*\)/  $(printf "${G}")\1$(printf "${N}")\t\2/p" "$0"
    printf "\n${G}dev loop:${N}   edit files in %s -> %s login -> bats test.bats\n" "$PIE_KIT" "$0"
    printf "${G}overrides:${N}  PIE_IMG PIE_VOL PIE_LOGIN PIE_KIT PIE_RES PIE_DISPLAY (see header)\n"
}

# ---- dispatch ---------------------------------------------------------------
main() {
    _c=${1:-login}
    [ $# -eq 0 ] || shift
    case "$_c" in -h|--help) _c=help ;; esac
    if type "cmd_$_c" >/dev/null 2>&1; then
        "cmd_$_c" "$@"
    else
        err "unknown command: $_c"
        cmd_help >&2
        exit 1
    fi
}
main "$@"

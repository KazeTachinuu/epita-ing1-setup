#!/bin/sh
# Run the kit's tests in throwaway x86_64 containers (docker; on arm64
# hosts they run emulated, slower).
#
#   tests/run.sh                  every suite against the working tree
#   tests/run.sh t-install.sh     one suite
#   REV=HEAD~1 tests/run.sh ...   against a committed version instead
#   SH=bash|dash|busybox-ash      shell running install.sh (default dash)
#
# Suites: t-install.sh (PIE login, plugin clones), t-sshfs.sh (real FUSE
# mount, from-home case), t-setup.sh (real GitHub/PyPI downloads).
set -eu
T=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$T")
CACHE="$T/.cache"
# the CRI skeleton the kit's install.sh replaces (must stay a superset)
CRI_REPO=https://github.com/epita/epita-default-confs
CRI_PIN=50fd6db224bed4ab5728ec4b6692e0f78763f40e

mkdir -p "$CACHE"
docker build -q --platform linux/amd64 -t kit-bench "$T" >/dev/null
if [ ! -d "$CACHE/cri" ]; then
    git clone -q "$CRI_REPO" "$CACHE/cri.tmp"
    git -C "$CACHE/cri.tmp" checkout -q "$CRI_PIN"
    rm -rf "$CACHE/cri.tmp/.git" && mv "$CACHE/cri.tmp" "$CACHE/cri"
fi
KIT=$ROOT
if [ -n "${REV:-}" ]; then
    KIT="$CACHE/rev"; rm -rf "$KIT"; mkdir -p "$KIT"
    git -C "$ROOT" archive "$REV" | tar -x -C "$KIT"
fi

run() {
    case $1 in t-sshfs.sh) opts=--privileged ;; *) opts="-u student" ;; esac
    # shellcheck disable=SC2086
    docker run --rm --platform linux/amd64 $opts -e SH="${SH:-dash}" \
        -v "$KIT:/kit:ro" -v "$CACHE/cri:/cri:ro" -v "$T:/tests:ro" \
        kit-bench timeout 900 bash "/tests/$1"
}
[ $# -gt 0 ] || set -- t-install.sh t-sshfs.sh t-setup.sh
rc=0
for t in "$@"; do run "$t" || rc=1; done
exit $rc

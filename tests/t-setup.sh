#!/bin/bash
# setup.sh end to end (real GitHub/PyPI downloads), then bashrc, submit and
# gdbinit on the result. Configs are served from /kit (PIE_BASE), standing
# in for raw.githubusercontent.com at the PIN.
pass=0 fail=0
ok()  { pass=$((pass+1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
ko()  { fail=$((fail+1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; }
chk() { local m=$1; shift; if "$@"; then ok "$m"; else ko "$m"; fi; }
(cd /kit && exec python3 -m http.server 8000 >/dev/null 2>&1) &
sleep 1
# a non-default AFS_DIR: nothing may assume ~/afs
export PIE_BASE=http://localhost:8000 AFS_DIR=$HOME/myafs
E=$AFS_DIR/.confs
setup() { sh "${1:-/kit/setup.sh}" > /tmp/out 2>&1; }

echo "== setup.sh"
echo "-- S1 first install (real downloads)"
setup; rc=$?
chk "exit 0" [ $rc = 0 ]
for b in starship fzf rg fd bat tldr; do
    chk "$b runs: $("$E/bin/$b" --version 2>&1 | head -1)" \
        sh -c '"$1" --version >/dev/null' _ "$E/bin/$b"
done
chk "GEF present" [ -s "$E/gef.py" ]
chk "fzf key bindings present" [ -s "$E/fzf-key-bindings.bash" ]
chk "coding-style-check runs" \
    sh -c '"$1/bin/coding-style-check" --help >/dev/null 2>&1' _ "$E"
chk "ignore present" [ -x "$E/bin/ignore" ]
chk "version stamp" grep -qE '^[0-9a-f]{40}$' "$E/.kit"
chk "no .new.* leftovers" [ -z "$(ls -a "$E" | grep '^\.new')" ]
chk "~/.vimrc linked" [ "$(readlink ~/.vimrc)" = "$E/vimrc" ]

echo "-- S2 rerun converges (nothing re-downloaded)"
setup; rc=$?
chk "exit 0" [ $rc = 0 ]
chk "every step skipped" [ "$(grep -c 'fetching\|updating' /tmp/out)" = 0 ]

echo "-- S3 installed 0.26.10 is not the pinned 0.26.1"
printf '#!/bin/sh\necho "bat 0.26.10"\n' > "$E/bin/bat"
setup
chk "bat updated" grep -q 'bat: updating' /tmp/out
chk "now the real 0.26.1" \
    sh -c '"$1/bin/bat" --version | grep -q "bat 0.26.1 "' _ "$E"

echo "-- S4 a release with an unexpected layout skips, the rest goes on"
sed 's#"bat-v$BAT_V-$ARCH-unknown-linux-musl/bat"#"nope/bat"#' \
    /kit/setup.sh > /tmp/setup-broken.sh
rm -f "$E/bin/bat" "$E/bin/tldr" "$E/gef.py"
setup /tmp/setup-broken.sh; rc=$?
chk "exit 0" [ $rc = 0 ]
chk "bat warned" grep -q 'bat: .*skipped' /tmp/out
chk "tldr still installed" [ -x "$E/bin/tldr" ]
chk "GEF still installed" [ -s "$E/gef.py" ]
chk "no .new.* leftovers" [ -z "$(ls -a "$E" | grep '^\.new')" ]
setup

echo "-- S5 bashrc with a non-default AFS_DIR"
out=$(bash -ic 'command -v rg; kit | head -1' 2>/dev/null </dev/null)
chk "extras on PATH ($(echo "$out" | head -1))" grep -q "$E/bin/rg" <<<"$out"
chk "kit cheatsheet found" grep -q 'EPITA PIE kit' <<<"$out"

echo "-- S6 submit"
git config --global user.name t; git config --global user.email t@t
git config --global init.defaultBranch master
R=/tmp/repo; git init -q --bare /tmp/remote.git; git init -q $R
cp /kit/clang-format $R/.clang-format; mkdir -p $R/src $R/tests
printf 'int main(void)\n{\n    return 0;\n}\n' > $R/src/ok.c
printf 'int f(void){return 1;}\n' > $R/tests/bad.c
git -C $R add -A; git -C $R commit -qm init
git -C $R remote add origin /tmp/remote.git; git -C $R push -q -u origin master
sub() { (cd "$1" && bash -ic "submit $2" </dev/null 2>&1); }
out=$(sub $R/src tag1)
chk "from src/: names tests/bad.c" grep -q 'tests/bad.c' <<<"$out"
chk "from src/: no tag created" [ -z "$(git -C $R tag)" ]
clang-format -i $R/tests/bad.c; git -C $R commit -qam fmt
echo x > $R/dirty.c
out=$(sub $R tag1); chk "dirty tree refused" grep -q uncommitted <<<"$out"
rm $R/dirty.c
sub $R/src tag1 >/dev/null
chk "clean: tag pushed" \
    git --git-dir=/tmp/remote.git rev-parse -q --verify refs/tags/tag1
sub /tmp tag2 >/dev/null
chk "outside a repo: refused" [ -z "$(git -C $R tag -l tag2)" ]

echo "-- S7 gdb loads GEF from AFS_DIR"
out=$(gdb -q -batch -ex 'gef config gef.disable_color' /bin/true 2>&1)
chk "GEF active in gdb" grep -q 'gef.disable_color' <<<"$out"

echo "== $pass passed, $fail failed"
[ $fail = 0 ]

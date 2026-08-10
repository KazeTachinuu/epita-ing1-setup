#!/usr/bin/env bats
# The kit's contract, nothing else: a student logs in, the kit applies,
# and it can never break a login or destroy a file.
#
#   bats pie/test.bats   (needs docker + the nixos-pie image)

KIT="$BATS_TEST_DIRNAME"
H="$KIT/harness.sh"
export PIE_VOL=pie-afs-bats

setup_file()    { "$H" reset >/dev/null; }
teardown_file() { "$H" reset >/dev/null; }

run_pie() { "$H" run "$@"; }    # simulated PIE login (kit auto-seeded), then cmd

@test "login links every kit file into place" {
    for f in $(sed -n 's/^link //p' "$KIT/install.sh"); do
        [ -e "$KIT/$f" ] || continue    # optional, user-provided
        run run_pie "readlink \$HOME/.$f"
        [ "$output" = "/home/${PIE_LOGIN:-test.user}/afs/.confs/$f" ]
    done
}

@test "vimrc applies: 4-space indent and 80-col guide vs stock's 8/none" {
    stock=$("$H" stock 'vim -c "call writefile([&ts . \",\" . &et . \",\" . &cc], \"/tmp/r\")" -c qa >/dev/null 2>&1 </dev/null; cat /tmp/r')
    kit=$(run_pie 'vim -c "call writefile([&ts . \",\" . &et . \",\" . &cc], \"/tmp/r\")" -c qa >/dev/null 2>&1 </dev/null; cat /tmp/r')
    [ "$stock" = "8,0," ] && [ "$kit" = "4,1,80" ]
}

@test "bashrc applies: cc99 compiles the piscine way" {
    run run_pie 'printf "int main(void)\n{\n    return 0;\n}\n" > m.c && bash -ic "cc99 m.c -o m" 2>/dev/null && ./m && echo ok'
    [ "$output" = "ok" ]
}

@test "re-login is a silent no-op" {
    run run_pie 'AFS_DIR=$HOME/afs $HOME/afs/.confs/install.sh 2>&1'
    [ -z "$output" ]
}

@test "a pre-existing real file is backed up, never destroyed" {
    run run_pie 'rm $HOME/.vimrc && echo mine > $HOME/.vimrc; AFS_DIR=$HOME/afs $HOME/afs/.confs/install.sh; grep -q mine $HOME/.vimrc.local-backup && readlink $HOME/.vimrc >/dev/null && echo safe'
    [ "$output" = "safe" ]
}

@test "install.sh exits 0 even when everything is wrong (login safety)" {
    run run_pie 'AFS_DIR=/nonexistent $HOME/afs/.confs/install.sh; echo "exit=$?"'
    [ "$output" = "exit=0" ]
}

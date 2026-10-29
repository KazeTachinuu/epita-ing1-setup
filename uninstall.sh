#!/bin/sh
# kit uninstall: remove what the kit added, put back what it replaced.
# Run as `sh "$KIT_DIR/uninstall.sh"` (bashrc's `kit uninstall`). Works
# offline from the kit home alone, whatever kit version installed it:
#   standalone  replays $KIT_DIR/.journal backwards (written by setup.sh,
#               install.sh and packages.sh), then removes the kit home
#   AFS layout  (.confs, no journal, also installs from before journals)
#               removes the kit's fixed set of files from .confs and moves
#               .confs.backup back; other files in .confs are never touched
# Exit 0 when done or nothing to do, 1 when something the user changed
# since install was left in place (each printed as [-] kept <path>: <why>).

KIT_DIR="${KIT_DIR:-${AFS_DIR:-$HOME/afs}/.confs}"
# what the kit puts in .confs: setup.sh's FILES, then what it fetches or
# creates there (keep in sync with setup.sh)
FIXED="install.sh cheatsheet clang-format starship.toml vimrc vimrc.exam
       bashrc gdbinit inputrc tmux.conf alacritty.toml packages.sh
       uninstall.sh .kit bin pylib gef.py fzf-key-bindings.bash vim/pack/kit"
TAB=$(printf '\t')

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    G='\033[1;32m' Y='\033[1;33m' D='\033[2m' N='\033[0m'
else
    G= Y= D= N=
fi
say()  { printf "${G}[+]${N} %s\n" "$1"; }
skip() { printf "${D}[=]${N} ${D}%s${N}\n" "$1"; }
rc=0
kept() { printf "${Y}[-]${N} kept %s: %s\n" "$1" "$2"; rc=1; }
# a path is taken even by a dangling symlink
there() { [ -e "$1" ] || [ -L "$1" ]; }

# undo_link <dst> <src> <backup>: the link goes only if it still points
# where the kit put it; then the moved-aside original comes back
undo_link() {
    if [ "$(readlink "$1" 2>/dev/null)" = "$2" ]; then
        rm -f "$1"
    elif there "$1"; then
        kept "$1" "changed since install, no longer the kit's link"
    fi
    [ -n "$3" ] && there "$3" || return 0
    if there "$1"; then
        kept "$3" "your original, $1 is in the way"
    else
        mv "$3" "$1" && say "restored $1"
    fi
}

# undo_line <file> <line>: delete that exact whole line, every other byte
# of the file as it is now stays. Rewritten in place (cat >), so the
# file's mode, owner and any symlink to it are kept.
undo_line() {
    if grep -qxF -e "$2" "$1" 2>/dev/null; then
        t=$(mktemp) || { kept "$1" "cannot make a temp file"; return; }
        L=$2 awk '$0 != ENVIRON["L"]' "$1" > "$t" && cat "$t" > "$1"
        rm -f "$t"
    elif grep -q '# epita-kit$' "$1" 2>/dev/null; then
        kept "$1" "the kit line was edited since install"
    fi
}

# vim's undo history is the user's: in standalone ~/.vim is the kit's
# vim dir, so its undo/ moves out to a real ~/.vim/undo before the kit
# home goes (a file of the same name already there wins)
keep_undo() {
    u="$KIT_DIR/vim/undo"
    [ -n "$(ls -A "$u" 2>/dev/null)" ] || return 0
    there "$HOME/.vim" || mkdir "$HOME/.vim"
    if ! there "$HOME/.vim/undo"; then
        mv "$u" "$HOME/.vim/undo" && return
    fi
    for f in "$u"/* "$u"/.[!.]*; do
        there "$f" && ! there "$HOME/.vim/undo/${f##*/}" \
            && mv "$f" "$HOME/.vim/undo/"
    done
}

uninstall_journal() {
    # newest first: a later action is undone before the one it built on
    entries=$(awk '{ l[NR] = $0 } END { for (i = NR; i; i--) print l[i] }' \
        "$KIT_DIR/.journal")
    pkgs=
    while IFS=$TAB read -r type a b c; do
        case $type in
        link) undo_link "$a" "$b" "$c" ;;
        line) undo_line "$a" "$b" ;;
        pkg) pkgs="$pkgs $b" ;;
        esac
    done <<EOF
$entries
EOF
    # packages.sh in the kit home knows the package manager and when to
    # ask for sudo, as it did at install
    [ -z "$pkgs" ] || sh "$KIT_DIR/packages.sh" remove $pkgs || rc=1
    keep_undo
    # never rm -rf something that is not a kit home
    case $KIT_DIR in /?*/?*) ;; *) kept "$KIT_DIR" "not a kit home"; return ;;
    esac
    [ "$KIT_DIR" != "$HOME" ] || { kept "$KIT_DIR" "is \$HOME"; return; }
    rm -rf "$KIT_DIR" && say "removed $KIT_DIR"
    # directories the kit created, emptied by the above: removed unless
    # something else lives in them now
    while IFS=$TAB read -r type a b c; do
        [ "$type" = dir ] && rmdir "$a" 2>/dev/null
    done <<EOF
$entries
EOF
}

# a path into the fixed set (or the kit's vim dir, which goes too when
# the kit made it and it is now empty)
in_fixed() {
    for f in $FIXED vim; do
        case $1 in "$KIT_DIR/$f" | "$KIT_DIR/$f"/*) return 0 ;; esac
    done
    return 1
}

uninstall_afs() {
    afs=${KIT_DIR%/.confs}
    for f in $FIXED; do rm -rf "${KIT_DIR:?}/$f"; done
    rmdir "$KIT_DIR/vim/pack" "$KIT_DIR/vim" 2>/dev/null
    # over sshfs the extras and plugins live locally: ~/.pie, and ~/.vim
    # when install.sh made it (undo history in it stays)
    if [ "${KIT_MODE:-}" = sshfs ] || [ "$(df -PT "$KIT_DIR" 2>/dev/null \
        | awk 'NR==2 {print $2}')" = fuse.sshfs ]; then
        rm -rf "$HOME/.pie"
        if [ ! -L "$HOME/.vim" ] && [ -e "$HOME/.vim/.kit-created" ]; then
            rm -rf "$HOME/.vim/pack/kit" "$HOME/.vim/.kit-created"
            rmdir "$HOME/.vim/pack" "$HOME/.vim" 2>/dev/null
        fi
    fi
    # the user's files from before the kit (setup.sh's first run)
    for f in "$afs/.confs.backup"/* "$afs/.confs.backup"/.[!.]*; do
        there "$f" || continue
        if there "$KIT_DIR/${f##*/}"; then
            kept "$f" "$KIT_DIR/${f##*/} is in the way"
        else
            mv "$f" "$KIT_DIR/" && say "restored $KIT_DIR/${f##*/}"
        fi
    done
    rmdir "$afs/.confs.backup" 2>/dev/null
    # the kit's links into .confs: one whose file came back from the
    # backup stays (the CRI install.sh links it too), one left dangling
    # goes. ~/.config may be a link into AFS: its kit links are named.
    for l in "$HOME"/.[!.]* "$HOME/.config/tmux/tmux.conf" \
        "$HOME/.config/alacritty/alacritty.toml" \
        "$HOME/.config/starship.toml"; do
        [ -L "$l" ] && [ ! -e "$l" ] && in_fixed "$(readlink "$l")" \
            && rm -f "$l"
    done
    say "removed the kit from $KIT_DIR"
}

# everything runs from main, on the last line: the script is read whole
# before it deletes the kit home it lives in
main() {
    if [ -f "$KIT_DIR/.journal" ]; then
        uninstall_journal
    elif case $KIT_DIR in */.confs) true ;; *) false ;; esac &&
        { [ -e "$KIT_DIR/.kit" ] ||
          [ -e "${KIT_DIR%/.confs}/.confs.backup" ]; }; then
        uninstall_afs
    else
        skip "nothing to uninstall"
        return 0
    fi
    if [ $rc = 0 ]; then
        say "kit uninstalled; open a new shell"
    else
        say "kit uninstalled, except what is listed as kept above"
    fi
    return $rc
}
main "$@"

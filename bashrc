# EPITA PIE bashrc - bash is the PIE default shell (zsh is not installed)
[[ $- != *i* ]] && return

# History that survives many terminals
HISTSIZE=100000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize globstar autocd

export EDITOR=vim
export UBSAN_OPTIONS=print_stacktrace=1

# Prompt: git's own contrib prompt (branch, dirty state, colors), with the
# plain fallback if git's contrib dir ever moves. Path resolves through the
# git derivation itself, so it works on any PIE image, exams included.
GITC="$(git --exec-path 2>/dev/null)/../../share/git/contrib/completion"
if [ -r "$GITC/git-prompt.sh" ]; then
    . "$GITC/git-prompt.sh"
    [ -r "$GITC/git-completion.bash" ] && . "$GITC/git-completion.bash"
    GIT_PS1_SHOWDIRTYSTATE=1 GIT_PS1_SHOWUNTRACKEDFILES=1 GIT_PS1_SHOWCOLORHINTS=1
    PROMPT_COMMAND='__git_ps1 "\[\e[36m\]\w\[\e[0m\]" " \$ " " (%s)"'
else
    __branch() { git branch --show-current 2>/dev/null | sed 's/.*/ (&)/'; }
    PS1='\[\e[36m\]\w\[\e[33m\]$(__branch)\[\e[0m\] \$ '
fi

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push --follow-tags'

# Compile the piscine way: moulinette builds with -Wall -Wextra -Werror and
# grades ASAN failures; UBSAN is free and catches signed overflow. -Wvla
# because the style bans VLAs. cc99 builds are valgrind/rr-compatible
# (ASAN is not, use ccsan OR valgrind, never both).
alias cc99='gcc -std=c99 -Wall -Wextra -Wvla -Werror -pedantic -g3'
alias ccsan='gcc -std=c99 -Wall -Wextra -Wvla -Werror -pedantic -g3 -fsanitize=address,undefined'

# Criterion test suites (preinstalled). Function, not alias: libraries
# must come after sources on the link line.
cctest() { gcc -std=c99 -Wall -Wextra -Wvla -Werror -g3 "$@" -lcriterion; }

# cccov test.c src.c: criterion suite with a coverage report
cccov() {
    gcc -std=c99 -Wall -Wextra -Werror -g3 --coverage "$@" -lcriterion || return
    ./a.out
    lcov -q -c -d . -o .cov.info && genhtml -q .cov.info -o coverage \
        && echo "coverage/index.html"
}

# submit <tag>: the moulinette flow - clean tree, formatted, annotated
# tag, push with tags. The forgotten tag or unformatted tree is the
# classic zero; this refuses both.
submit() {
    [ $# -eq 1 ] || { echo 'usage: submit <tagname>' >&2; return 2; }
    [ -z "$(git status --porcelain)" ] \
        || { echo 'submit: uncommitted changes, commit first' >&2; return 1; }
    if [ -e "$(git rev-parse --show-toplevel)/.clang-format" ] && command -v clang-format >/dev/null; then
        git ls-files '*.c' '*.h' | xargs -r clang-format --Werror --dry-run 2>/dev/null \
            || { echo 'submit: unformatted files, run: clang-format -i *.c *.h' >&2; return 1; }
    fi
    git tag -a "$1" -m "$1" && git push --follow-tags
}

# Optional layers - every line inert unless you installed the thing.
# nix extras (see install.sh):
[ -r ~/.nix-profile/share/fzf/key-bindings.bash ] && . ~/.nix-profile/share/fzf/key-bindings.bash
# AFS-persistent extras (installed by setup.sh):
[ -d ~/afs/.confs/bin ] && PATH="$HOME/afs/.confs/bin:$PATH"
command -v starship >/dev/null && eval "$(starship init bash)"
command -v fzf >/dev/null && [ -r ~/afs/.confs/fzf-key-bindings.bash ] \
    && . ~/afs/.confs/fzf-key-bindings.bash
# fd makes Ctrl-T/fzf respect .gitignore and skip build dirs
command -v fd >/dev/null \
    && export FZF_DEFAULT_COMMAND='fd --type f' \
              FZF_CTRL_T_COMMAND='fd --type f' FZF_ALT_C_COMMAND='fd --type d'

# `kit` shows what the kit gives you and why; hinted once per session
kit() { cat ~/afs/.confs/cheatsheet 2>/dev/null || echo "kit: not installed"; }
if [ -t 0 ] && [ -r ~/afs/.confs/cheatsheet ] && [ ! -e /tmp/.kit-hint ]; then
    touch /tmp/.kit-hint 2>/dev/null
    printf '\e[2mkit: type "kit" for the cheatsheet\e[0m\n'
fi

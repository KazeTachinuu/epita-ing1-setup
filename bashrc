# EPITA PIE bashrc - bash is the PIE default shell (zsh is not installed)
[[ $- != *i* ]] && return

# History that survives many terminals
HISTSIZE=100000          # lines kept in memory per shell (default 500)
HISTFILESIZE=100000      # lines kept in ~/.bash_history (default 500)
HISTCONTROL=ignoreboth   # skip duplicates and space-prefixed commands
# histappend: append to the history file instead of overwriting it
# globstar:   ** in globs matches recursively (src/**/*.c)
# autocd:     a bare directory name cd's into it
shopt -s histappend globstar autocd

export EDITOR=vim                        # editor git/crontab/etc. open
export UBSAN_OPTIONS=print_stacktrace=1  # UBSAN reports show the call stack, not just file:line

# Prompt: git's own contrib prompt (branch, dirty state, colors), with the
# plain fallback if git's contrib dir ever moves. Path resolves through the
# git derivation itself, so it works on any PIE image, exams included.
GITC="$(git --exec-path 2>/dev/null)/../../share/git/contrib/completion"
if [ -r "$GITC/git-prompt.sh" ]; then
    . "$GITC/git-prompt.sh"
    [ -r "$GITC/git-completion.bash" ] && . "$GITC/git-completion.bash"
    # DIRTYSTATE: * unstaged / + staged; UNTRACKEDFILES: %; COLORHINTS colors them
    GIT_PS1_SHOWDIRTYSTATE=1 GIT_PS1_SHOWUNTRACKEDFILES=1 GIT_PS1_SHOWCOLORHINTS=1
    # 3-arg __git_ps1 rebuilds PS1 each prompt: <cwd><branch-in-format> $
    PROMPT_COMMAND='__git_ps1 "\[\e[36m\]\w\[\e[0m\]" " \$ " " (%s)"'
else
    __branch() { git branch --show-current 2>/dev/null | sed 's/.*/ (&)/'; }
    PS1='\[\e[36m\]\w\[\e[33m\]$(__branch)\[\e[0m\] \$ '
fi

alias ls='ls --color=auto'          # color-code file types
alias ll='ls -lah'                  # -l long, -a dotfiles too, -h human sizes
alias grep='grep --color=auto'      # highlight the match
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'            # gc "message"
alias gp='git push --follow-tags'   # also pushes annotated tags on pushed commits

# One flag set for every helper: identical diagnostics in all four builds.
#   -std=c99 -pedantic  ISO C99; -pedantic diagnoses GNU extensions (std alone doesn't)
#   -Wall -Wextra       curated warning sets for likely-bug constructs
#   -Werror             warnings become errors: clean or no binary
#   -Wvla               VLAs are legal C99, nothing else flags them
#   -g3                 -g plus macro info: gdb can expand #defines
CC99FLAGS='-std=c99 -Wall -Wextra -Wvla -Werror -pedantic -g3'
alias cc99="gcc $CC99FLAGS"
# ASAN: runtime traps for out-of-bounds, use-after-free, leaks (~2x slower;
# owns the process memory map, so incompatible with valgrind/rr - use cc99
# builds for those). UBSAN: traps signed overflow, null deref, bad shifts;
# near-zero cost.
alias ccsan="gcc $CC99FLAGS -fsanitize=address,undefined"

# Criterion test suites (preinstalled). Function, not alias: libraries
# must come after sources on the link line.
cctest() { gcc $CC99FLAGS "$@" -lcriterion; }

# cccov test.c src.c: criterion suite with a coverage report
cccov() {
    gcc $CC99FLAGS --coverage "$@" -lcriterion || return
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
# skipped when the nix-extras copy above already loaded the bindings
command -v fzf >/dev/null && [ -r ~/afs/.confs/fzf-key-bindings.bash ] \
    && ! declare -F __fzf_history__ >/dev/null \
    && . ~/afs/.confs/fzf-key-bindings.bash
# fd skips .gitignored files and build dirs by default; --type f/d = files/dirs
# only. DEFAULT_COMMAND feeds bare fzf, CTRL_T the file picker, ALT_C the cd picker.
command -v fd >/dev/null \
    && export FZF_DEFAULT_COMMAND='fd --type f' \
              FZF_CTRL_T_COMMAND='fd --type f' FZF_ALT_C_COMMAND='fd --type d'

# `kit` shows what the kit gives you; hinted once per session
kit() {
    local f=~/afs/.confs/cheatsheet
    [ -r "$f" ] || { echo 'kit: not installed'; return 1; }
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        awk 'NR==1      { printf "\033[1m%s\033[0m\n", $0; next }
             /^exams/   { printf "\033[2m%s\033[0m\n", $0; next }
             /^[a-z0-9]/{ printf "\033[1;34m%s\033[0m\n", $0; next }
             /^  \S/    { printf "  \033[36m%-26s\033[0m\033[2m%s\033[0m\n",
                                 substr($0, 3, 26), substr($0, 31); next }
             { print }' "$f"
    else
        cat "$f"
    fi
}
if [ -t 0 ] && [ -r ~/afs/.confs/cheatsheet ] && [ ! -e "/tmp/.kit-hint-$UID" ]; then
    touch "/tmp/.kit-hint-$UID" 2>/dev/null
    printf '\e[2mkit: type "kit" for the cheatsheet\e[0m\n'
fi

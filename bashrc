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
# UBSAN reports show the call stack, not just file:line
export UBSAN_OPTIONS=print_stacktrace=1

# Prompt: git's own contrib prompt (branch, dirty state, colors), with the
# plain fallback if git's contrib dir ever moves. Path resolves through the
# git derivation itself, so it works on any PIE image, exams included.
GITC="$(git --exec-path 2>/dev/null)/../../share/git/contrib/completion"
if [ -r "$GITC/git-prompt.sh" ]; then
    . "$GITC/git-prompt.sh"
    [ -r "$GITC/git-completion.bash" ] && . "$GITC/git-completion.bash"
    # DIRTYSTATE: * unstaged / + staged; UNTRACKEDFILES: %; COLORHINTS colors
    GIT_PS1_SHOWDIRTYSTATE=1 GIT_PS1_SHOWUNTRACKEDFILES=1
    GIT_PS1_SHOWCOLORHINTS=1
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
alias gp='git push --follow-tags'   # also pushes annotated tags

# One flag set for every helper: identical diagnostics in all four builds.
#   -std=c99 -pedantic  ISO C99; -pedantic flags GNU extensions too
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

# submit <tag>: moulinette submission. Refuses a dirty or unformatted
# tree and requires the annotated tag, then pushes with tags.
submit() {
    [ $# -eq 1 ] || { echo 'usage: submit <tagname>' >&2; return 2; }
    [ -z "$(git status --porcelain)" ] \
        || { echo 'submit: uncommitted changes, commit first' >&2; return 1; }
    if [ -e "$(git rev-parse --show-toplevel)/.clang-format" ] &&
        command -v clang-format >/dev/null; then
        git ls-files '*.c' '*.h' |
            xargs -r clang-format --Werror --dry-run 2>/dev/null ||
            { echo 'submit: unformatted, run: clang-format -i *.c *.h' >&2
              return 1; }
    fi
    git tag -a "$1" -m "$1" && git push --follow-tags
}

# Optional layers - every line inert unless you installed the thing.
# nix extras (see install.sh):
[ -r ~/.nix-profile/share/fzf/key-bindings.bash ] &&
    . ~/.nix-profile/share/fzf/key-bindings.bash
# extras (installed by setup.sh): ~/.pie local over sshfs, AFS on campus
[ -d ~/afs/.confs/bin ] && PATH="$HOME/afs/.confs/bin:$PATH"
[ -d ~/.pie/bin ] && PATH="$HOME/.pie/bin:$PATH"
command -v starship >/dev/null && eval "$(starship init bash)"
# skipped when the nix-extras copy above already loaded the bindings
for _kb in ~/.pie/fzf-key-bindings.bash ~/afs/.confs/fzf-key-bindings.bash; do
    command -v fzf >/dev/null && [ -r "$_kb" ] \
        && ! declare -F __fzf_history__ >/dev/null && . "$_kb"
done; unset _kb
# fd skips .gitignored files and build dirs; --type f/d = files/dirs only.
# DEFAULT_COMMAND feeds bare fzf, CTRL_T the file picker, ALT_C the cd one.
command -v fd >/dev/null \
    && export FZF_DEFAULT_COMMAND='fd --type f' \
              FZF_CTRL_T_COMMAND='fd --type f' FZF_ALT_C_COMMAND='fd --type d'

# kit: cheatsheet; kit status: check for updates; kit update: reinstall
kit() {
    local d=~/afs/.confs f=~/afs/.confs/cheatsheet cur latest
    local raw=https://raw.githubusercontent.com/KazeTachinuu/epita-ing1-setup
    case "${1:-}" in
    update)
        curl -fsSL "$raw/master/setup.sh" | sh; return ;;
    status)
        # same markers as setup.sh: [*] info [=] converged [-] warn
        local B='\033[1;34m' Y='\033[1;33m' D='\033[2m' N='\033[0m'
        if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then B= Y= D= N=; fi
        cur=$(cat "$d/.kit" 2>/dev/null)
        if [ -z "$cur" ]; then
            printf "${Y}[-]${N} kit: version unknown, run: kit update\n"
            return 1
        fi
        # released PIN on master; only a real 40-hex sha is trusted
        latest=$(curl -fsSL --max-time 3 "$raw/master/setup.sh" \
                     2>/dev/null | sed -n 's/^PIN=\([0-9a-f]\{40\}\)$/\1/p')
        if [ -z "$latest" ]; then
            printf "${Y}[-]${N} kit: offline, cannot check\n"; return 1
        elif [ "$cur" = "$latest" ]; then
            printf "${D}[=] kit: up to date (%.7s)${N}\n" "$cur"
        else
            printf "${B}[*]${N} kit: update available (%.7s -> %.7s)," \
                "$cur" "$latest"
            printf " run: kit update\n"
        fi; return ;;
    esac
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
if [ -t 0 ] && [ -r ~/afs/.confs/cheatsheet ] &&
    [ ! -e "/tmp/.kit-hint-$UID" ]; then
    touch "/tmp/.kit-hint-$UID" 2>/dev/null
    printf '\e[2mkit: type "kit" for the cheatsheet\e[0m\n'
    # once per boot: mention a kit update if one is out (3s cap, offline-safe)
    kit status 2>/dev/null | grep 'update available' || true
fi

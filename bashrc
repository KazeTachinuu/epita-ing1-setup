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
# grades ASAN failures; UBSAN is free and catches signed overflow.
alias cc99='gcc -std=c99 -Wall -Wextra -Werror -pedantic -g3'
alias ccsan='gcc -std=c99 -Wall -Wextra -Werror -pedantic -g3 -fsanitize=address,undefined'

# Criterion test suites (preinstalled). Function, not alias: libraries
# must come after sources on the link line.
cctest() { gcc -std=c99 -Wall -Wextra -Werror -g3 "$@" -lcriterion; }

# Optional layers - every line inert unless you installed the thing.
# nix extras (see install.sh):
[ -r ~/.nix-profile/share/fzf/key-bindings.bash ] && . ~/.nix-profile/share/fzf/key-bindings.bash
# AFS-persistent extras (see README "Optional extras"):
[ -d ~/afs/.confs/bin ] && PATH="$HOME/afs/.confs/bin:$PATH"
command -v starship >/dev/null && eval "$(starship init bash)"
[ -r ~/afs/.confs/blesh/ble.sh ] && . ~/afs/.confs/blesh/ble.sh

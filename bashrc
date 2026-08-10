# EPITA PIE bashrc - bash is the PIE default shell (zsh is not installed)
[[ $- != *i* ]] && return

# History that survives many terminals
HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize

export EDITOR=vim

# Prompt: cyan path, yellow git branch
__branch() { git branch --show-current 2>/dev/null | sed 's/.*/ (&)/'; }
PS1='\[\e[36m\]\w\[\e[33m\]$(__branch)\[\e[0m\] \$ '

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push --follow-tags'

# Compile the piscine way: moulinette builds with -Wall -Wextra -Werror and
# grades ASAN failures, so develop with the same flags from day one.
alias cc99='gcc -std=c99 -Wall -Wextra -Werror -pedantic -g'
alias ccsan='gcc -std=c99 -Wall -Wextra -Werror -pedantic -g -fsanitize=address'

# Link against criterion for test suites (preinstalled on the PIE)
alias cctest='gcc -std=c99 -Wall -Wextra -Werror -g -lcriterion'

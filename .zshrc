export PATH=$PATH:~/.local/bin/
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
autoload -U compinit; compinit
zstyle ':completion:*' menu select
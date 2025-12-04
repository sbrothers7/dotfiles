# eval "$(starship init zsh)"
export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"

export PATH=$PATH:~/.local/bin/

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

alias pyinit='source ~/.pyvenv/bin/activate'
alias shrl='source ~/.zshrc'
alias ff='fastfetch'

# alias for enabling/disabling tiling WM when testing
alias tdisable='
    yabai --stop-service; \
    skhd --stop-service
'

alias tenable='
    yabai --start-service; \
    skhd --start-service
'

alias nwtools=~/Coding/Other/scripts/nwtools.sh

cd ()
{
    if [ -n "$1" ]; then
	builtin cd "$@" && ls
    else
	builtin cd ~ && ls
    fi
}

source $HOME/agkozak-zsh-prompt/agkozak-zsh-prompt.plugin.zsh

clear

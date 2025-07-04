eval "$(starship init zsh)"
export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"

# if this shell is not interactive, stop processing ~/.zshrc
export PATH=$PATH:~/.local/bin/

alias config='/usr/bin/git --git-dir=/Users/preluminance/.cfg/ --work-tree=/Users/preluminance'
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

alias pyinit='source ~/.pyvenv/bin/activate'
alias shrl='source ~/.zshrc'
alias ff='fastfetch'


cd ()
{
	if [ -n "$1" ]; then
		builtin cd "$@" && ls
	else
		builtin cd ~ && ls
	fi
}


clear
ff
# fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc

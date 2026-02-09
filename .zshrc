# eval "$(starship init zsh)"
export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"

eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH=$PATH:~/.local/bin/

source .secrets # github tokens, etc. are stored here

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[ -f /opt/homebrew/etc/profile.d/autojump.sh ] && . /opt/homebrew/etc/profile.d/autojump.sh

alias shrl='source ~/.zshrc'
alias ff='fastfetch'

# alias for enabling/disabling tiling WM when testing
alias tdisable='
    yabai --stop-service; \
    skhd --stop-service
    source $HOME/.zprofile 
'

alias tenable='
    yabai --start-service; \
    skhd --start-service
'
alias pyinit='source venv/bin/activate'

alias nwtools=~/Coding/Other/scripts/nwtools.sh

cnc() {
    ffmpeg -i "$1" \
	-c:v libx265 -crf 28 -pix_fmt yuv420p \
	-profile:v main -tag:v hvc1 \
	-c:a aac -b:a 160k \
	-movflags +faststart \
    temp.mp4
    ffmpeg -i temp.mp4 -vf "scale=854:480" output.mp4
    rm temp.mp4
}

cd ()
{
    if [ -n "$1" ]; then
	builtin cd "$@" && ls
    else
	builtin cd ~ && ls
    fi
}

source $HOME/agkozak-zsh-prompt/agkozak-zsh-prompt.plugin.zsh


# Menu items, defaults and paths used by the rest of the installer

# TODO: qutebrowser config

# ============ CONFIG ============
CATEGORIES=( WM ZSH Utilities Casks Defaults Other Quit )
SUBCATS=( ${CATEGORIES:#Quit} )

CATEGORY_WM=( "yabai" "skhd" "borders" "sketchybar")
CATEGORY_ZSH=( "zsh-syntax-highlighting" "zsh-autosuggestions" "starship" "agkozak-zsh-prompt")
CATEGORY_Utilities=( "neovim" "fastfetch" "lf" "yt-dlp" "btop" "ffmpeg" "python" "node" "openjdk" "lua" "qemu" "mono" "armadillo" "lazygit" "llvm" "autojump")
CATEGORY_Casks=( "kitty" "iterm2" "helium-browser" "brave-browser" "karabiner-elements" "jordanbaird-ice" "middleclick" "stats" "linearmouse" "pearcleaner" "yellowdot" "iina" "mpv" "command-x" "prismlauncher" "bluestacks" "element" "discord" "gimp" "obs")
CATEGORY_Defaults=( "Minimalist" "No Animations" "QoL" "Revamped Finder" "sbrothers7 Settings")
CATEGORY_Other=( "Fonts" "Rosetta 2" "KISJ App Bundle")

DEFAULT_WM=( 1 2 )
DEFAULT_ZSH=( 1 2 4 )
DEFAULT_Utilities=( 1 2 3 4 5 6 )
DEFAULT_Casks=( 1 3 5 7 8 12 15 17 20)
DEFAULT_Defaults=( 1 2 5 )
DEFAULT_Other=( 1 )

# Dotfiles the script may link: zshrc is ~/.zshrc, the rest are ~/.config/<name>. Other .config folders are never linked.
# "Use dotfiles" links the ones whose program is installed; "Select programs to use dotfiles" links the ticked ones.
# Kept by hand, so add a name here when a folder is added to .config
CATEGORY_Dotfiles=( "zshrc" "borders" "btop" "ctpv" "fastfetch" "jgit" "karabiner" "kitty" "lf" "linearmouse" "nvim" "rstudio" "sketchybar" "skhd" "starship" "stats" "tmux" "yabai" )
DEFAULT_Dotfiles=( {1..${#CATEGORY_Dotfiles}} )
typeset -gi DOTFILES_MODE=1   # 1 use dotfiles, 2 only picked programs, 3 don't use dotfiles
# Dotfile folder -> program it configures, where the names differ
typeset -gA DOTFILE_PROGRAM=( nvim neovim karabiner karabiner-elements )

# Tapped during install and untapped at the end when no installed formulae need them
TAPS=( "asmvik/formulae" "felixkratz/formulae" )

FONT_CASKS=( "sf-symbols" "font-sf-mono" "font-sf-pro" "font-hack-nerd-font" "font-jetbrains-mono" "font-fira-code" "font-sf-mono-nerd-font-ligaturized" )

TITLE="Installation Setup"

DOTS_DIR="$HOME/sbro7dots"
BACKUP_DIR="$HOME/sbro7dots-backups/$(date +%Y%m%d-%H%M%S)"
STATE_FILE="$HOME/.cache/sbro7dots-selections"
PROGRESS_FILE="$HOME/.cache/sbro7dots-progress"
INSTALL_LOG="$HOME/.cache/sbro7dots-install.log"
typeset -gi USE_OVERLAY=1   # loading screen during install; toggled in the main menu
SUDOERS_TMP="/etc/sudoers.d/sbro7dots-install"

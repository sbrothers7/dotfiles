# Arch Linux menu items, the packages behind them, defaults and paths

# ============ CONFIG ============
CATEGORIES=( Desktop Shell Utilities Apps System Theming Quit )
SUBCATS=( ${CATEGORIES:#Quit} )

CATEGORY_Desktop=( "hyprland" "waybar" "quickshell" "fuzzel" "rofi" "wlogout" "swayosd" "wob" "swaync" "Screenshots" "Clipboard" "Korean input" "wallust" "nwg-displays" "nwg-look" )
CATEGORY_Shell=( "zsh" "zsh-autosuggestions" "zsh-syntax-highlighting" "spaceship-prompt" "fzf" "zoxide" )
CATEGORY_Utilities=( "neovim" "fastfetch" "btop" "yazi" "lsd" "ripgrep" "fd" "jq" "trash-cli" "yt-dlp" "ffmpeg" "python" "nvtop" "cava" "github-cli" "imagemagick" "7zip" "ddcutil" )
CATEGORY_Apps=( "kitty" "thunar" "brave-bin" "vesktop-bin" "signal-desktop" "element-desktop" "obs-studio" "gimp" "kdenlive" "mpv" "loupe" "libreoffice-still" "prismlauncher" "steam" "vscodium-bin" "pavucontrol" "blueman" "qalculate-gtk" "mousepad" "zoom" "kakaotalk" "proton-vpn-gtk-app" )
CATEGORY_System=( "Audio (PipeWire)" "Bluetooth" "NetworkManager" "Printing" "SDDM" "NVIDIA" "zram" "Flatpak" )
CATEGORY_Theming=( "Fonts" "Qt/GTK theming" "Cursor & icons" "minegrub theme" )

DEFAULT_Desktop=( {1..15} )
DEFAULT_Shell=( {1..6} )
DEFAULT_Utilities=( {1..12} )
DEFAULT_Apps=( 1 2 3 4 10 11 16 17 )
DEFAULT_System=( 1 2 3 5 )
DEFAULT_Theming=( 1 2 3 )
# Preselect the driver when an NVIDIA card (PCI vendor 0x10de) is present
grep -qsx 0x10de /sys/bus/pci/devices/*/vendor && DEFAULT_System+=( 6 )

# Menu item -> packages, where it is more than the one package of the same name
typeset -gA PKGS=(
    hyprland "hyprland uwsm xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent hyprlock hypridle hyprpaper swaybg qt5-wayland qt6-wayland"
    quickshell "quickshell qt6-5compat"
    rofi "rofi rofimoji wtype"
    Screenshots "hyprshot grim slurp swappy"
    Clipboard "cliphist wl-clipboard"
    "Korean input" "fcitx5 fcitx5-gtk fcitx5-qt fcitx5-hangul fcitx5-configtool"
    python "python python-pip"
    thunar "thunar thunar-archive-plugin thunar-volman tumbler gvfs gvfs-mtp ffmpegthumbnailer xarchiver"
    "Audio (PipeWire)" "pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pamixer playerctl"
    Bluetooth "bluez bluez-utils"
    NetworkManager "networkmanager network-manager-applet"
    Printing "cups system-config-printer avahi nss-mdns"
    SDDM "sddm"
    NVIDIA "nvidia-open-dkms nvidia-utils nvidia-settings libva-nvidia-driver"
    zram "zram-generator"
    Flatpak "flatpak"
    Fonts "noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-liberation ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-fira-code ttf-fantasque-nerd otf-font-awesome adobe-source-code-pro-fonts ttf-victor-mono"
    "Qt/GTK theming" "kvantum qt5ct qt6ct gtk-engine-murrine xsettingsd"
    "Cursor & icons" "bibata-cursor-theme-bin flat-remix flat-remix-gtk"
)
# Not packages: set up by their own step
NON_PACKAGES=( "minegrub theme" )
# Need the multilib repository
MULTILIB_ITEMS=( "steam" )

# Dotfiles the script may link from arch/: zsh is ~/.config/zsh plus the ~/.zshrc, ~/.zprofile and ~/.alias links,
# the rest are ~/.config/<name>. ~/.local/bin is always linked. Kept by hand, so add a name here when a folder is added.
CATEGORY_Dotfiles=( "zsh" "hypr" "waybar" "quickshell" "fuzzel" "rofi" "wlogout" "wob" "kitty" "nvim" "fastfetch" "btop" "yazi" "fcitx5" "Thunar" "Kvantum" "qt5ct" "qt6ct" "gtk-3.0" "gtk-4.0" "xsettingsd" "nwg-look" )
DEFAULT_Dotfiles=( {1..${#CATEGORY_Dotfiles}} )
typeset -gi DOTFILES_MODE=1   # 1 use dotfiles, 2 only picked programs, 3 don't use dotfiles
# Dotfile folder -> package it configures, where the names differ (a package, not a menu item)
typeset -gA DOTFILE_PROGRAM=( hypr hyprland nvim neovim fcitx5 fcitx5 Thunar thunar Kvantum kvantum gtk-3.0 gtk3 gtk-4.0 gtk4 )

TITLE="Installation Setup (Arch Linux)"

DOTS_DIR="$HOME/sbro7dots"
STOW_PACKAGE="arch"
BACKUP_DIR="$HOME/sbro7dots-backups/$(date +%Y%m%d-%H%M%S)"
STATE_FILE="$HOME/.cache/sbro7dots-selections"
PROGRESS_FILE="$HOME/.cache/sbro7dots-progress"
INSTALL_LOG="$HOME/.cache/sbro7dots-install.log"
typeset -gi USE_OVERLAY=1   # loading screen during install; toggled in the main menu
SUDOERS_TMP="/etc/sudoers.d/sbro7dots-install"

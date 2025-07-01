#!/bin/zsh

# Colors
BOLD_BLUE="\033[1;34m"
BOLD_GREEN="\033[1;32m"
BOLD_RED="\033[1;31m"
RESET="\033[0m"

# Install xCode CLI tools
echo "${BOLD_BLUE}Installing commandline tools...${RESET}"
xcode-select --install

echo "${BOLD_BLUE}Checking Homebrew Installation...${RESET}"
if ! command -v brew >/dev/null 2>&1; then
  echo "${BOLD_RED}Homebrew is not installed. Please install Homebrew first: https://brew.sh/${RESET}"
  exit 1
fi

## Taps
echo "${BOLD_BLUE}Tapping Brew...${RESET}"
brew tap FelixKratz/formulae
brew tap koekeishiya/formulae

## Formulae
echo "${BOLD_BLUE}Installing Brew Formulae...${RESET}"
brew install yabai borders skhd < /dev/null
brew install gsl boost libomp wget jq ripgrep bear mas gh < /dev/null
read -n1 -rep "${BOLD_BLUE}Install sketchybar? [y/n]: ${RESET}" choice
if [[ choice =~ ^[Yy]$ ]]; then
  brew install sketchybar ifstat switchaudio-osx lua < /dev/null # sketchybar & dependencies for config
fi
brew install lf ctpv btop neovim < /dev/null # utilities
brew install git lazygit stow < /dev/null
brew install starship fzf zsh-syntax-highlighting zsh-autosuggestions autojump < /dev/null # zsh
brew install ffmpeg mono node python armadillo < /dev/null # big packages

## Casks
echo "${BOLD_BLUE}Installing Brew Casks...${RESET}"
brew install --cask kitty \
brave-browser \
karabiner-elements
read -n1 -rep "${BOLD_BLUE}Install other utilities? [y/n]: ${RESET}" choice
if [[ choice =~ ^[Yy]$ ]]; then
  brew install --cask
  zoom \
  sol \
  slimhud \
  command-x \
  yellowdot \
  middleclick \
  mpv
else
  echo "${BOLD_GREEN}Skipping..."
fi

### Fonts
brew install --cask sf-symbols font-sf-mono font-sf-pro font-hack-nerd-font font-jetbrains-mono font-fira-code

read -n1 -rep "${BOLD_BLUE}Automatically change macOS defaults? [y/n]: ${RESET}" choice
if [[ choice =~ ^[Yy]$ ]]; then
  # macOS Settings
  echo "${BOLD_BLUE}Changing macOS defaults...${RESET}"
  defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.spaces spans-displays -bool false
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock "mru-spaces" -bool "false"
  defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
  defaults write com.apple.LaunchServices LSQuarantine -bool false
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write NSGlobalDomain _HIHideMenuBar -bool true
  defaults write com.apple.screencapture location -string "$HOME/Desktop"
  defaults write com.apple.screencapture disable-shadow -bool true
  defaults write com.apple.screencapture type -string "png"
  defaults write com.apple.finder DisableAllAnimations -bool true
  defaults write com.apple.Finder AppleShowAllFiles -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  defaults write com.apple.finder ShowStatusBar -bool false
  defaults write com.apple.finder CreateDesktop -bool false
  killall Finder
  defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
  defaults write NSGlobalDomain WebKitDeveloperExtras -bool true
  defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
  defaults write -g NSWindowShouldDragOnGesture -bool true
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

# Copying configuration files
echo "${BOLD_BLUE}Planting Configuration Files...${RESET}"
[ ! -d "$HOME/dotfiles" ] && git clone "https://github.com/sbrothers7/dotfiles" $HOME/dotfiles

# Installing Fonts
echo "${BOLD_BLUE}Installing fonts...${RESET}"
git clone "https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized.git" /tmp/SFMono_Nerd_Font
mv /tmp/SFMono_Nerd_Font/* $HOME/Library/Fonts
rm -rf /tmp/SFMono_Nerd_Font/

curl -L "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf" -o $HOME/Library/Fonts/sketchybar-app-font.ttf

# SBar Lua
(git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && cd /tmp/SbarLua/ && make install && rm -rf /tmp/SbarLua/)

source $HOME/dotfiles/.zshrc
cfg config --local status.showUntrackedFiles no

echo "${BOLD_GREEN}All dependencies installed successfully.${RESET}"

echo "${BOLD_BLUE}Attempting to stow items to root folder...${RESET}"
rm -rf .zprofile
cd dotfiles
stow .
echo "${BOLD_BLUE}If operation fails, remove all dotfile in root then try manually.${RESET}"

# Start Services
echo "${BOLD_BLUE}Starting Services (grant permissions)...${RESET}"
yabai --start-service
skhd --start-service
brew services start sketchybar
brew services start borders

csrutil status
echo "(optional) Disable SIP for advanced yabai features."
echo ""

read -n1 -rep "${BOLD_BLUE}Add sudoer for yabai features? [y/n]: ${RESET}" choice
if [[ $choice =~ ^[Yy]$ ]]; then
  $(whoami) ALL = (root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | awk "{print \$1;}") $(which yabai) --load-sa' to '/private/etc/sudoers.d/yabai
else
  echo "${BOLD_GREEN}Installation complete. Enter${RESET} source .zshrc ${BOLD_GREEN} to apply changes to zsh.${RESET}"
fi

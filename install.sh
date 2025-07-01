#!/bin/zsh

# Colors
BOLD_BLUE="\033[1;34m"
BOLD_GREEN="\033[1;32m"
BOLD_RED="\033[1;31m"
RESET="\033[0m"

# Homebrew installation
echo "${BOLD_BLUE}\nChecking homebrew installation...${RESET}"
if ! command -v brew >/dev/null 2>&1; then
  echo "${BOLD_RED}Homebrew is not installed.${RESET}"
  echo "${BOLD_GREEN}Attempting to install homebrew...${RESET}"
 
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/install_homebrew.sh
  chmod +x /tmp/install_homebrew.sh
  /bin/bash /tmp/install_homebrew.sh

  echo >> $HOME/.zprofile
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"

  echo "${BOLD_GREEN}Successfully installed homebrew. Continuing installation...${RESET}"
else
  echo "${BOLD_GREEN}Found homebrew installation. Continuing..."
fi

# Install xCode CLI tools
echo "${BOLD_BLUE}Checking command line tools installation...${RESET}"
if xcode-select -p &>/dev/null; then
  echo "${BOLD_GREEN}xCode command line tools is already installed. Continuing...${RESET}"
else
  xcode-select --install
fi

# Taps
echo "${BOLD_BLUE}\nTapping brew...${RESET}"
brew tap FelixKratz/formulae
brew tap koekeishiya/formulae

# Formulae
echo "${BOLD_BLUE}Installing brew formulae...${RESET}"

echo -n "${BOLD_BLUE}\nInstall tiling window manager? [y/n]: ${RESET}"
read -k 1 yabai
echo
if [[ $yabai =~ ^[Yy]$ ]]; then
  brew install yabai skhd < /dev/null
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

echo -n "${BOLD_BLUE}\nInstall borders? [y/n]: ${RESET}"
read -k 1 borders
echo
if [[ $yabai =~ ^[Yy]$ ]]; then
  brew install borders < /dev/null
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

echo -n "${BOLD_BLUE}\nInstall sketchybar? [y/n]: ${RESET}" 
read -k 1 sketchybar
echo
if [[ $sketchybar =~ ^[Yy]$ ]]; then
  brew install sketchybar ifstat switchaudio-osx lua < /dev/null # sketchybar & dependencies for config
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

echo "${BOLD_BLUE}\nInstalling git and stow...${RESET}"
brew install git lazygit stow < /dev/null

echo -n "${BOLD_BLUE}\nInstall CLI utilities? [y/n]: "
read -k 1 cliutil
echo
if [[ $cliutil =~ ^[Yy]$ ]]; then
  brew install lf ctpv btop neovim fastfetch yt-dlp < /dev/null # utilities
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

echo -n "${BOLD_BLUE}\nInstall zsh utilities? [y/n]: ${RESET}"
read -k 1 zshutil
echo
if [[ $zshutil =~ ^[Yy]$ ]]; then
  brew install starship fzf zsh-syntax-highlighting zsh-autosuggestions autojump < /dev/null # zsh
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

echo "${BOLD_BLUE}\nInstalling dependencies..."
brew install gsl boost libomp wget jq ripgrep bear mas gh < /dev/null

echo -n "${BOLD_BLUE}\nInstall ffmpeg? [y/n]: ${RESET}"
read -k 1 ffmpeg
echo
if [[ $ffmpeg =~ ^[Yy]$ ]]; then
  brew install ffmpeg < /dev/null
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

echo -n "${BOLD_BLUE}\nInstall python and node? [y/n]: ${RESET}"
read -k 1 pynode
echo
if [[ $pynode =~ ^[Yy]$ ]]; then
  brew install node python < /dev/null
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

echo -n "${BOLD_BLUE}\nInstall mono and armadillo? [y/n]: ${RESET}"
read -k 1 monoarma 
echo
if [[ $monoarma =~ ^[Yy]$ ]]; then
  brew install mono armadillo < /dev/null
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

## Casks
echo "${BOLD_BLUE}\nInstalling brew casks...${RESET}"
brew install --cask kitty \
brave-browser \
karabiner-elements
echo -n "${BOLD_BLUE}\nInstall other utility casks? [y/n]: ${RESET}"
read -k 1 utility 
echo
if [[ $utility =~ ^[Yy]$ ]]; then
  brew install --cask
  zoom \
  sol \
  slimhud \
  command-x \
  yellowdot \
  middleclick \
  linearmouse \
  mpv
else
  echo "${BOLD_GREEN}Skipping..."
fi

### Fonts

echo -n "${BOLD_BLUE}\nAutomatically change macOS defaults? [y/n]: ${RESET}"
read -k 1 choice
echo
if [[ $choice =~ ^[Yy]$ ]]; then
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
  echo "${BOLD_GREEN}Successfully changed macOS defaults.${RESET}"
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

# Installing Fonts
echo -n "${BOLD_BLUE}\nInstall fonts and symbols? [y/n]: ${RESET}"
read -k 1 fonts
echo 
if [[ $fonts =~ ^[Yy]$ ]]; then
  echo "${BOLD_BLUE}\nInstalling fonts...${RESET}"
  brew install --cask sf-symbols font-sf-mono font-sf-pro font-hack-nerd-font font-jetbrains-mono font-fira-code
  git clone "https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized.git" /tmp/SFMono_Nerd_Font
  mv /tmp/SFMono_Nerd_Font/* $HOME/Library/Fonts
  rm -rf /tmp/SFMono_Nerd_Font/
else
  echo "${BOLD_GREEN}Skipping...${RESET}"
fi

# SBar Lua
if [[ $sketchybar =~ ^[Yy]$ ]]; then
  curl -L "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf" -o $HOME/Library/Fonts/sketchybar-app-font.ttf

  (git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && cd /tmp/SbarLua/ && make install && rm -rf /tmp/SbarLua/)
fi

# Copying configuration files
echo -n "${BOLD_BLUE}\nUse config files? [y/n]: ${RESET}"
read -k 1 config
echo
if [[ $config =~ ^[Yy]$ ]]; then
  echo "${BOLD_BLUE}Planting configuration files...${RESET}"
  [ ! -d "$HOME/dotfiles" ] && git clone "https://github.com/sbrothers7/dotfiles" $HOME/dotfiles
  source $HOME/dotfiles/.zshrc
  
  echo "${BOLD_BLUE}Attempting to stow items to root folder...${RESET}"
  rm -rf .zprofile
  cd dotfiles
  stow .
  echo "${BOLD_BLUE}If operation fails, remove all dotfile in root then try manually.${RESET}"
fi

echo "${BOLD_GREEN}All dependencies installed successfully.${RESET}"

# Start Services
echo "${BOLD_BLUE}\nStarting services (grant permissions)...${RESET}"
yabai --start-service
skhd --start-service
if [[ $sketchybar =~ ^[Yy]$ ]]; then
  brew services start sketchybar
fi
if [[ $borders =~ ^[Yy]$ ]]; then
  brew services start borders
fi

echo "${BOLD_BLUE}\nChecking SIP status...${RESET}"
csrutil status
echo "${BOLD_BLUE}Partly disable SIP for advanced yabai features.\nThis can be achieved by going into recovery mode, then entering:"
echo "${RESET}csrutil enable --without fs --without debug --without nvram"
echo "${BOLD_BLUE}into the terminal.\n"

echo -n "${BOLD_BLUE}Add sudoer for yabai features? [y/n]: ${RESET}"
read -k 1 yabaisudoer 
echo
if [[ $yabaisudoer =~ ^[Yy]$ ]]; then
  echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
fi

echo "${BOLD_GREEN}Installation complete.${RESET}"
echo "source .zshrc\n${BOLD_BLUE}to apply changes."

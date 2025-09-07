#!/usr/bin/env zsh

ok()    { print -P "%B%F{green}✔ $*%f%b"; }
warn()  { print -P "%F{yellow}$*%f"; }
err()   { print -P "%B%F{red}✖ $*%f%b"; }
info()  { print -P "%B%F{blue}$*%f%b"; }
dim()   { print -P "%F{black}$*%f"; }


# ============ CONFIG ============
CATEGORIES=( WM ZSH Utilities Casks Defaults Other Quit )
SUBCATS=( ${CATEGORIES:#Quit} )

CATEGORY_WM=( "yabai" "skhd" "borders" "sketchybar")
CATEGORY_ZSH=( "zsh-syntax-highlighting" "zsh-autosuggestions" "starship" )
CATEGORY_Utilities=( "neovim" "fastfetch" "lf" "yt-dlp" "btop" "ffmpeg" "mono" "armadillo" "lazygit" "llvm" "python" "node" "openjdk" "lua" "qemu" )
CATEGORY_Casks=( "kitty" "brave-browser" "karabiner-elements" "sol" "middleclick" "linearmouse" "slimhud" "yellowdot" "iina" "command-x" "alt-tab" "prismlauncher" "bluestacks" "discord" "gimp" "obs" "qutebrowser")
CATEGORY_Defaults=( "Minimalist" "No Animations" "QoL" "Revamped Finder")
CATEGORY_Other=( "Fonts" "Rosetta 2" "KISJ App Bundle")

DEFAULT_WM=( 1 2 3 4 )
DEFAULT_ZSH=( 1 2 3 )
DEFAULT_Utilities=( 1 2 3 4 )
DEFAULT_Casks=( 1 2 3 4 5 )
DEFAULT_Defaults=( 1 2 )
DEFAULT_Other=( 1 )

TITLE="Installation Setup"
PROMPT_MAIN="%BEnter number to open a submenu%b\n([c]onfirm, [l]ist, [h]elp, [r]eset all, [q]uit):"
PROMPT_SUB="%BEnter number to toggle selection%b\n([a]ll, [n]one, [l]ist, [h]elp, [b]ack):"

# ============ STATE ============
typeset -a selected_WM selected_ZSH selected_Utilities selected_Casks selected_Defaults selected_Other

init() {
    for cat in "${SUBCATS[@]}"; do
        sel_var="selected_${cat}"
        items_var="CATEGORY_${cat}"
        defs_var="DEFAULT_${cat}"

        eval "$sel_var=()"
        eval "len=\${#${items_var}[@]}"
        for ((i=1; i<=len; i++)); do eval "${sel_var}[$i]=0"; done
        eval 'for d in "${'"$defs_var"'[@]}"; do
                  (( d>=1 && d<=len )) && '"${sel_var}"'[$d]=1
              done'
    done
}


# ============ MENUS ============
render_main() {
    print -P "%B%F{blue}================================"
    print -P "       $TITLE"
    print -P "================================%f%b"
    local -i i
    for (( i=1; i<=${#CATEGORIES[@]}; i++ )); do
        printf "%2d) %s\n" $i "${CATEGORIES[$i]}"
    done
    print -P "%B%F{blue}--------------------------------%f%b"
    print -Pn -- "$PROMPT_MAIN "
}

render_submenu() {
    local -r cat="$1" buf="$2"
    local -a items; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
    local -a sel;   eval "sel=( \"\${selected_${cat}[@]}\" )"
    print -P "%B%F{blue}============ ${cat} ============%f%b"
    local -i i
    for (( i=1; i<=${#items[@]}; i++ )); do
        local mark='[ ]'; [[ "${sel[$i]}" == "1" ]] && mark='[x]'
        printf "%2d) %s %s\n" $i "$mark" "${items[$i]}"
    done
    print -P "%B%F{blue}--------------------------------%f%b"
    print -Pn -- "$PROMPT_SUB "
    [[ -n "$buf" ]] && print -r -- "$buf"
}

print_all_selections() {
    local cat
    for cat in "${CATEGORIES[@]}"; do
        [[ "$cat" == "Quit" ]] && continue
        local -a items sel; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
        eval "sel=( \"\${selected_${cat}[@]}\" )"
        local -i shown=0 i
        for (( i=1; i<=${#items[@]}; i++ )); do
            if [[ "${sel[$i]}" == "1" ]]; then
                (( shown == 0 )) && info "[$cat]"
                print -r -- "  - ${items[$i]}"
                (( shown++ ))
            fi
        done
         
        # print -n -- "\nPress any key for next"
        # read -k
        # clear
    done
    print -n -- "\nPress any key to exit"
    read -k
    clear
}

# ============ HELP ============
help_main() {
    cat <<'HLP'

    MAIN MENU HELP:

    Number keys       Open category

    c                 Confirm and run installers
    
    l                 List current selections
    
    h                 Help
    
    q                 Quit



HLP
    print -n -- "Press any key to exit"
    read -k
    clear
}
help_sub() {
    cat <<'HLP'

    SUBMENU HELP:

    Number keys       Toggle item (if < 10 items)
                      (for 10+ items) type digits then 
                      press Enter/Space to toggle
     
    Backspace         Erase last digit
    Delete  
    
    a                 Select all in this submenu
    
    n                 Deselect all in this submenu
    
    l                 List global selections
    
    h                 Help
    
    b                 Back to main menu



HLP
    print -n -- "Press any key to exit"
    read -k
    clear
}

read_key() {
    # Reads one keystroke into global REPLY, no print, immediate
    IFS= read -rk 1 -s
}

is_digit() { [[ "$1" == <-> ]]; }          # single digit 0..9
is_backspace() { [[ "$1" == $'\x7f' || "$1" == $'\b' ]]; }
is_enter() { [[ "$1" == $'\n' || "$1" == $'\r' || "$1" == ' ' ]]; }

# Toggle handler
toggle_item() {
    local -r cat="$1"; local -i idx="$2"
    local -a items; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
    (( idx >= 1 && idx <= ${#items[@]} )) || { print -r -- "Out of range: $idx"; return; }
    local cur; eval "cur=\${selected_${cat}[$idx]}"
    if [[ "$cur" == "1" ]]; then
        eval "selected_${cat}[$idx]=0"
        print -r -- "Deselected: ${items[$idx]}"
    else
        eval "selected_${cat}[$idx]=1"
        print -r -- "Selected:   ${items[$idx]}"
    fi
}

# Submenu loop (instant keys)
submenu_loop() {
    local -r cat="$1"
    local -a items; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
    local buf=""
    while true; do
        render_submenu "$cat" "$buf"
        read_key
        clear
        
        local k="$REPLY"
        
        # Fast path: single-digit toggle if <=9 items
        if is_digit "$k" && (( ${#items[@]} <= 9 )); then
            toggle_item "$cat" "$k"
            continue
        fi
        
        # Build number buffer (for multi-digit indices or any size)
        if is_digit "$k"; then
            buf+="$k"
            # Optional: live toggle when buffer already valid and next char not a digit
            continue
        fi
        
        # Apply buffered number on Enter/Space
        if is_enter "$k"; then
            if [[ -n "$buf" ]]; then
                toggle_item "$cat" "$buf"
                buf=""
            fi
            continue
        fi
        
        # Backspace/Delete clears buffer char-by-char
        if is_backspace "$k"; then
            [[ -n "$buf" ]] && buf="${buf[1,-2]}"   # chop last char
            continue
        fi
        
        case "$k" in
            a) # all
                local -i i; for (( i=1; i<=${#items[@]}; i++ )); do eval "selected_${cat}[$i]=1"; done
                print -r -- "Selected every item."
                ;;
            n) # none
                local -i i; for (( i=1; i<=${#items[@]}; i++ )); do eval "selected_${cat}[$i]=0"; done
                print -r -- "Deselected every item.";
                ;;
            l) print_all_selections ;;
            h) help_sub ;;
            b) return 0 ;;
            q) print -r -- "Exiting."; exit 0 ;;
            *) print;;
        esac
    done
}

install_formula() {
    local formula="$1"
    if brew list --formula --versions "$formula" >/dev/null 2>&1; then
        warn "$formula already installed"
    else
        brew install "$formula"
    fi
}

install_cask() {
    local cask="$1"
    if brew list --cask --versions "$cask" >/dev/null 2>&1; then
        warn "$cask already installed"
    else
        brew install --cask "$cask"
    fi
}

gather_pkgs() {
    typeset -ga formulae=() casks=() nonbrew=()
    local i cat j items_var sel_var len s

    for i in {1..${#SUBCATS[@]}}; do
        cat="${SUBCATS[$i]}"

        items_var="CATEGORY_${cat}"
        sel_var="selected_${cat}"

        eval "len=\${#${items_var}[@]}"
        for (( j=1; j<=len; j++ )); do
            eval 's="${'"$sel_var"'[$j]}"'
            if [[ "$s" == 1 ]]; then
                if (( i == 4 )); then
                    eval 'casks+=( "${'"$items_var"'[$j]}" )'
                elif (( i > 4 )); then
                    eval 'nonbrew+=( "${'"$items_var"'[$j]}" )' # non brew-related
                else
                    eval 'formulae+=( "${'"$items_var"'[$j]}" )'
                fi
            fi
        done
    done
    
    # Deduplicate in zsh
    typeset -aU formulae=("${formulae[@]}")
    typeset -aU casks=("${casks[@]}")
    
    # echo "${formulae[@]}"
    # echo "${casks[@]}"
    # echo "${nonbrew[@]}"
}

in_array() {
    local index="$1"; shift
    local -a arr=( "$@" )

    (( ${arr[(Ie)$index]} ))
}

minimalist() {
    defaults write com.apple.dock autohide -bool true
    defaults write NSGlobalDomain _HIHideMenuBar -bool true
    defaults write com.apple.dock "static-only" -bool "true" && killall Dock
    defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool "false"
}

noanimation() {
    defaults write com.apple.finder DisableAllAnimations -bool true
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
}

fixfinder () {
    info "Applying global theme settings for Finder..."

    # list view
    info "Setting default Finder view to list view...}"
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    # Configure list view settings for all folders info "Configuring list view settings for all folders..."
    # Set default list view settings for new folders
    defaults write com.apple.finder FK_StandardViewSettings -dict-add ListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 12; "useRelativeDates" = 1; }'
    
    # Clear existing folder view settings to force use of default settings
    info "Clearing existing folder view settings..."
    defaults delete com.apple.finder FXInfoPanesExpanded 2>/dev/null || true
    defaults delete com.apple.finder FXDesktopVolumePositions 2>/dev/null || true
    
    # Set list view for all view types
    info "Setting list view for all folder types..."
    defaults write com.apple.finder FK_StandardViewSettings -dict-add ExtendedListViewSettings '{ "columns" = ( { "ascending" = 1; "identifier" = "name"; "visible" = 1; "width" = 300; }, { "ascending" = 0; "identifier" = "dateModified"; "visible" = 1; "width" = 181; }, { "ascending" = 0; "identifier" = "size"; "visible" = 1; "width" = 97; } ); "iconSize" = 16; "showIconPreview" = 0; "sortColumn" = "name"; "textSize" = 13; "useRelativeDates" = 1; }'
    
    # Sets default search scope to the current folder
    info "Setting default search scope to the current folder..."
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    
    # Remove trash items older than 30 days
    info "Removing trash items older than 30 days..."
    defaults write com.apple.finder "FXRemoveOldTrashItems" -bool "true"
    
    # Remove .DS_Store files to reset folder view settings
    info "Removing .DS_Store files to reset folder view settings..."
    find ~ -name ".DS_Store" -type f -delete 2>/dev/null || true
    
    # Show all filename extensions
    info "Showing all filename extensions in Finder..."
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    
    # Set the sidebar icon size to small
    info "Setting sidebar icon size to small..."
    defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
    
    # Show status bar in Finder
    info "Showing status bar in Finder..."
    defaults write com.apple.finder ShowStatusBar -bool true
    
    # Show path bar in Finder
    info "Showing path bar in Finder..."
    defaults write com.apple.finder ShowPathbar -bool true
    
    # Clean up Finder's sidebar
    info "Cleaning up Finder's sidebar..."
    defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
    defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
    defaults write com.apple.finder SidebarShowingiCloudDesktop -bool false

    
    # Restart Finder to apply changes
    ok "Finder has been restarted and settings have been applied."
    killall Finder
}

qol() {
    defaults write com.apple.LaunchServices LSQuarantine -bool false
    defaults write NSGlobalDomain KeyRepeat -int 1
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.spaces spans-displays -bool falsei

    # Screencapture
    defaults write com.apple.screencapture location -string "$HOME/Desktop"
    defaults write com.apple.screencapture disable-shadow -bool true
    defaults write com.apple.screencapture type -string "png"
    
    # Finder
    defaults write com.apple.Finder AppleShowAllFiles -bool true
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    defaults write com.apple.finder ShowStatusBar -bool true
    killall Finder
    
    # Other
    defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
    defaults write NSGlobalDomain WebKitDeveloperExtras -bool true
    defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
    defaults write -g NSWindowShouldDragOnGesture -bool true
    defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool "false"
}

fixyabai() {
    info "Use yabai scripting additions?" 
    read -k

    defaults write com.apple.finder CreateDesktop -bool true
    defaults write com.apple.dock "mru-spaces" -bool "false"
}



# Installers
run_installers() {
    clear

    # Homebrew installation
    info "Checking homebrew installation..."
    if ! command -v brew >/dev/null 2>&1; then
        err "Homebrew is not installed."
        info "Attempting to install homebrew..."
       
        curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/install_homebrew.sh
        chmod +x /tmp/install_homebrew.sh
        /bin/bash /tmp/install_homebrew.sh

        info "Setting PATH for homebrew..."
        print >> $HOME/.zprofile
        print 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"

        ok "Successfully installed homebrew. Continuing installation..."
    else
        ok "Found homebrew installation. Continuing..."
    fi
    
    # Install xCode CLI tools
    info "\nChecking command line tools installation..."
    if xcode-select -p &>/dev/null; then
        warn "xCode command line tools is already installed. Continuing..."
    else
        info "Installing xCode command line tools..."
        xcode-select --install
        ok "xCode command line tools successfully installed. Continuing..."
    fi
    
    gather_pkgs
    
    info "\nInstalling git and stow..."
    install_formula "git"
    install_formula "stow"
    
    # Formulae
    if (( ${#formulae[@]} )); then
        print
        info "Installing formulae..."
        for f in "${formulae[@]}"; do
            install_formula "$f"
        done
    else
        warn "No formulae selected."
    fi
    
    # Casks
    if (( ${#casks[@]} )); then
        info "\nInstalling casks..."
        for c in "${casks[@]}"; do
            install_cask "$c"
        done
    else
        warn "No casks selected."
    fi
    
    # Other

    # macOS defaults
    info "\nChanging macOS defaults..."

    if in_array "Minimalist" "${nonbrew[@]}"; then
        minimalist
        ok "Applied \"Minimalist\" preset"
    fi

    if in_array "No Animations" "${nonbrew[@]}"; then
        noanimation
        ok "Applied \"No Animations\" preset"
    fi
    if in_array "Revamped Finder" "${nonbrew[@]}"; then
        fixfinder
        ok "Applied \"Revamped Finder\" preset"
    fi

    if in_array "QoL" "${nonbrew[@]}"; then
        qol
        ok "Applied \"Quality of Life\" preset"
    fi

    if in_array "Rosetta 2" "${nonbrew[@]}"; then
    fi
    
    print
    ok "Finished setting macOS defaults"
    
    
    # Fonts
    if in_array "Fonts" "${nonbrew[@]}"; then
        info "\nInstalling fonts..."

        fonts=("sf-symbols" "font-sf-mono" "font-sf-pro" "font-hack-nerd-font" "font-jetbrains-mono" "font-fira-code")
        # printf '%s\n' "${fonts[@]}"

        for font in "${fonts[@]}"; do
            install_cask "$font"
        done
        
        git clone "https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized.git" /tmp/SFMono_Nerd_Font
        mv /tmp/SFMono_Nerd_Font/* $HOME/Library/Fonts
        rm -rf /tmp/SFMono_Nerd_Font/

        ok "Installed fonts"
    fi

    if in_array "Rosetta 2" "${nonbrew[@]}"; then
        info "\nInstalling Rosetta 2..."
        if /usr/bin/pgrep oahd >/dev/null 2>&1; then
            warn "Rosetta 2 is already installed"
        else
            softwareupdate --install-rosetta --agree-to-license
            ok "Installed Rosetta successfully"
        fi
    fi

    if in_array "KISJ App Bundle" "${nonbrew[@]}"; then
        info "\nInstalling KISJ Required Apps..."
        install_formula "mas"

        mas install 1645016851 # Bluebook
        mas install 1496582158 # Exam.net
        mas install 6450684725 # NWEA
        ok "Installed KISJ Apps"
    fi

    # Dotfiles

    DOTS_DIR="/Users/$USER/Downloads/testing/sbro7dots"
    BACKUP_DIR="$DOTS_DIR/../sbro7dots-backups/" 
    info "\nApplying sbrothers7 dotfiles..."

    if [ -d "$DOTS_DIR" ]; then 
        info "Found dotfiles directory. Upgrading..."
        cd "$DOTS_DIR"
        git stash && git pull
    else 
        if [ -d "$DOTS_DIR/../.config" ]; then
            warn "Found existing .config directory"
            mkdir "$BACKUP_DIR"
            mv "$DOTS_DIR/.config" "$BACKUP_DIR/.config"
            ok "Backed up existing configuration files to $BACKUP_DIR.config"
        fi
        
        info "Downloading sbrothers7 dotfiles..."
        git clone "https://github.com/sbrothers7/dotfiles" $DOTS_DIR
    fi

    cd "$DOTS_DIR/.config"
    dirs=(*(/))

    selpkg=("${selected_WM[@]}" "${selected_ZSH[@]}" "${selected_Utilities[@]}" "${selected_Casks[@]}" "${selected_Defaults[@]}" "${selected_Other[@]}")
    catpkg=("${CATEGORY_WM[@]}" "${CATEGORY_ZSH[@]}" "${CATEGORY_Utilities[@]}" "${CATEGORY_Casks[@]}" "${CATEGORY_Defaults[@]}" "${CATEGORY_Other[@]}")
    pkgtoinstall=()
    
    for i in {1..${#selpkg[@]}}; do
      if [[ ${selpkg[i]} -eq 1 ]]; then
        pkgtoinstall+=("${catpkg[i]}")
      fi
    done

    for pkg in "${dirs[@]}"; do
        if ! in_array "$pkg" "${pkgtoinstall[@]}"; then
            rm -rf "$DOTS_DIR/.config/$pkg"
        fi
    done

    info "Stowing..."
    cd $DOTS_DIR && stow .
}

# =============== MAIN LOOP ===============
main_loop() {
    while true; do
        render_main
        read_key
        clear
        local k="$REPLY"

        # Single-digit ( < 10 categories)
        if is_digit "$k" && (( ${#CATEGORIES[@]} <= 9 )); then
            local -i idx=$k
            if (( idx >= 1 && idx <= ${#CATEGORIES[@]} )); then
                local cat="${CATEGORIES[$idx]}"
                [[ "$cat" == "Quit" ]] && { info "Script exited."; exit 0; }
                submenu_loop "$cat"
            fi
            continue
        fi

        case "$k" in
            c)  # confirm
                print_all_selections
                print -Pn -- "%B%F{blue}Proceed with installation? [y/N]: %f%b"
                read_key; local y="$REPLY"
                if [[ "$y" == [yY] ]]; then run_installers; 
                    print
                    ok "All done!"; exit 0
                else 
                    clear
                    info "Cancelled."; fi
                    ;;
            l) print_all_selections ;;
            r) 
                init 
                ok "Reset selections to default"
                ;;
            h) help_main ;;
            q) info "Script exited."; exit 0 ;;
            $'\n'|$'\r'|' ') ;;  # ignore Enter/space here
            *) ;;                # ignore other keys
        esac
    done
}

clear

compat() {
    if [[ -z "${ZSH_VERSION:-}" ]]; then
        err "This script requires zsh. Please run it with zsh."
        exit 1
    fi
    
    if [[ ! -t 0 ]]; then
    warn "Non-interactive environment detected (stdin is not a TTY). Please use an interactive environment."
    exit 1
    else
        ok "Running in interactive environment"
    fi
    
    if [[ "$(uname -m)" == "arm64" ]]; then
        ok "Apple Silicon detected"
    else
        err "Intel (x86_64) detected. This script is exclusively for Apple Silicon Macs. Please use a different machine."
        exit 1
    fi
    
    if [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null)" == "1" ]]; then
        err "Running under Rosetta (x86_64 translation). Please disable Rosetta and run this script again."
        exit 1
    else
        ok "Running natively"
    fi
}

compat

info "Initializing..."
init
ok "Script ready"
print -n -- "Press any key to start"
read -k
clear

main_loop

# ============ macOS DEFAULTS PRESETS ============

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
    info "Setting default Finder view to list view..."
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
    defaults write com.apple.spaces spans-displays -bool false

    # Screencapture
    defaults write com.apple.screencapture location -string "$HOME/Desktop"
    defaults write com.apple.screencapture disable-shadow -bool true
    defaults write com.apple.screencapture type -string "png"
    
    # Finder
    defaults write com.apple.finder AppleShowAllFiles -bool true
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

# sbrothers7's own System Settings, read from a configured Mac (macOS 15)
personal() {
    local -i failed=0
    local tp

    # Trackpad: light click, tap to click (built-in and Magic Trackpad)
    for tp in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
        defaults write "$tp" FirstClickThreshold -int 0
        defaults write "$tp" SecondClickThreshold -int 0
        defaults write "$tp" Clicking -bool true
    done
    defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

    # Keyboard: key repeat, Globe key does nothing, F13 selects the next input source
    defaults write NSGlobalDomain InitialKeyRepeat -int 10
    defaults write NSGlobalDomain KeyRepeat -int 5
    defaults write com.apple.HIToolbox AppleFnUsageType -int 0
    # Hotkey 61 = "Select next source in Input menu"; parameters are (no character, F13 key code, function key flag)
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '{ enabled = 1; value = { parameters = (65535, 105, 8388608); type = standard; }; }'

    # Dock: 0.1s show/hide animation, no suggested or recent apps
    defaults write com.apple.dock autohide-time-modifier -float 0.1
    defaults write com.apple.dock show-recents -bool false

    # Desktop and appearance
    defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
    defaults write NSGlobalDomain AppleInterfaceStyle -string Dark

    # Menu bar: always visible, 24-hour clock with seconds and weekday, battery percentage, input menu, no Spotlight icon
    defaults write NSGlobalDomain _HIHideMenuBar -bool false
    defaults write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool true
    defaults write NSGlobalDomain AppleICUForce24HourTime -bool true
    defaults write com.apple.menuextra.clock ShowSeconds -bool true
    defaults write com.apple.menuextra.clock ShowAMPM -bool false
    defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
    defaults write com.apple.menuextra.clock ShowDate -int 0
    defaults write com.apple.menuextra.clock FlashDateSeparators -bool false
    defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
    defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true
    defaults write com.apple.TextInputMenu visible -bool true

    # Apple Intelligence off
    defaults write com.apple.CloudSubscriptionFeatures.optIn "545129924" -bool false

    # Lock screen: hide user name and photo, no large clock
    sudo defaults write /Library/Preferences/com.apple.loginwindow HideUserAvatarAndName -bool true
    sudo defaults write /Library/Preferences/com.apple.loginwindow UsesLargeDateTime -bool false

    # macOS only lets a terminal with Full Disk Access write accessibility settings
    if ! { defaults write com.apple.universalaccess reduceMotion -bool true &&
           defaults write com.apple.universalaccess reduceTransparency -bool true &&
           defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true; } 2>/dev/null; then
        note "Reduce motion, reduce transparency and control-scroll zoom need Full Disk Access for this terminal."
        note "Allow it in System Settings > Privacy & Security > Full Disk Access, then run the script again."
        failed=1
    fi

    killall Dock ControlCenter SystemUIServer 2>/dev/null
    # Applies keyboard, trackpad and shortcut changes without logging out
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    return $failed
}

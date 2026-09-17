# ============ TEST MODE ============
# Loaded by `install.sh --test`: the real menus, loading screen, resume and summary, with every install step faked.
# Nothing is installed or changed, and state lives in its own folder so a real unfinished install stays untouched.
# TEST_FAIL=<package> makes that package's fake install fail, to try the failure summary and Resume.

TEST_MODE=1
TITLE="Installation Setup (test mode)"
STATE_FILE="$HOME/.cache/sbro7dots-test/selections"
PROGRESS_FILE="$HOME/.cache/sbro7dots-test/progress"
INSTALL_LOG="$HOME/.cache/sbro7dots-test/install.log"
SUDOERS_TMP=""
NOTES=( "Test mode: nothing was installed or changed." )

# fake <seconds> <line...>: print the lines spread over the given time
fake() {
    local -F pause=$(( $1 / ($# - 1) ))
    local line; shift
    for line in "$@"; do
        print -r -- "$line"
        sleep $pause
    done
}

install_formula() {
    [[ -n "${INSTALLED[$1]}" ]] && { warn "$1 already installed"; return 0; }
    [[ "$1" == "$TEST_FAIL" ]] && { fake 1 "==> Fetching $1" "Error: $1: Failed to download resource (test failure)"; return 1; }
    fake 1.5 "==> Fetching $1" "==> Downloading https://ghcr.io/v2/homebrew/core/$1/blobs/sha256:4f1c0e" \
        "==> Pouring $1--1.0.arm64_sequoia.bottle.tar.gz" "🍺  /opt/homebrew/Cellar/$1/1.0: 128 files, 4.2MB"
}

install_cask() {
    [[ -n "${INSTALLED[$1]}" ]] && { warn "$1 already installed"; return 0; }
    [[ "$1" == "$TEST_FAIL" ]] && { fake 1 "==> Downloading $1" "Error: Download failed on Cask '$1' (test failure)"; return 1; }
    fake 2 "==> Downloading https://example.com/$1.dmg" "==> Installing Cask $1" \
        "==> Moving App '$1.app' to '/Applications/$1.app'" "🍺  $1 was successfully installed!"
}

install_homebrew() {
    [[ -x /opt/homebrew/bin/brew ]] && { ok "Found homebrew installation"; return 0; }
    fake 3 "==> Checking for sudo access" "==> Downloading and installing Homebrew..." "==> Installation successful!"
}

setup_brew()        { fake 1 "==> Tapping ${TAPS[1]}" "==> Tapping ${TAPS[2]}" "Trusted taps: ${TAPS[*]}"; }
install_rosetta()   { fake 2 "Installing Rosetta 2..." "Install of Rosetta 2 finished successfully"; }
install_kisj_apps() { fake 3 "==> Installing Bluebook" "==> Installing Exam.net" "==> Installing NWEA"; }
minimalist()        { fake 1 "Hiding the Dock and menu bar" "Restarting Dock"; }
noanimation()       { fake 1 "Turning off window and Finder animations"; }
fixfinder()         { fake 2 "Setting Finder list view" "Showing path bar and status bar" "Restarting Finder"; }
qol()               { fake 1.5 "Setting key repeat and screenshot options" "Showing hidden files" "Restarting Finder"; }
personal()          { fake 2 "Setting trackpad and keyboard" "Setting Dock, menu bar and lock screen" "Restarting Dock and Control Center"; }
get_dotfiles()      { fake 2 "Cloning into '$DOTS_DIR'..." "Resolving deltas: 100% done."; }
write_zshrc()       { fake 0.5 "Writing ~/.zshrc.local"; }
hook_zshrc()        { fake 0.3 "Checking that ~/.zshrc loads ~/.zshrc.local"; }
untap_unused()      { fake 1 "Kept ${TAPS[1]} because installed formulae come from it" "Untapped ${TAPS[2]}"; }

# Shows which dotfiles the real step would link
stow_dotfiles() {
    local -a picked
    local -i i
    local name
    for (( i = 1; i <= ${#CATEGORY_Dotfiles}; i++ )); do
        [[ "${selected_Dotfiles[i]}" == 1 ]] && picked+=( "${CATEGORY_Dotfiles[i]}" )
    done
    for name in "${CATEGORY_Dotfiles[@]}"; do
        dotfile_needed "$name" "${picked[@]}" && fake 0.2 "LINK: $name"
    done
    return 0
}

start_services() {
    local service
    for service in skhd borders sketchybar yabai; do
        in_array "$service" "${formulae[@]}" && fake 0.5 "Starting $service"
    done
    return 0
}

# Anything not faked above still can't touch this Mac
for cmd in brew defaults sudo stow git softwareupdate mas killall skhd yabai; do
    functions[$cmd]="print -r -- \"(test mode) skipped: $cmd \$*\""
done
unset cmd

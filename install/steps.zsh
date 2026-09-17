# Install steps, recovery and the full install sequence

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
        /opt/homebrew/bin/brew install --cask "$cask"
    fi
}

# ============ RECOVERY ============
# Finished steps are recorded in PROGRESS_FILE, so rerunning after an interruption skips them
typeset -gi STEP_INDEX=0 STEP_TOTAL=0 COUNT_ONLY=0
typeset -g STEP_NAME=""
typeset -ga FAILED_STEPS NOTES

# step [-a] <name> <command...>   (-a: run every time instead of once)
step() {
    local -i always=0
    [[ "$1" == -a ]] && { always=1; shift; }
    local name="$1"; shift
    if (( COUNT_ONLY )); then
        (( STEP_TOTAL++ ))
        return 0
    fi

    (( STEP_INDEX++ ))
    STEP_NAME="$name"
    progress ""
    if (( ! always )) && grep -qxF "$name" "$PROGRESS_FILE" 2>/dev/null; then
        ok "$name (done in an earlier run)"
        return 0
    fi
    info "\n==> $name"
    if "$@"; then
        (( always )) || print -r -- "$name" >> "$PROGRESS_FILE"
    else
        FAILED_STEPS+=( "$name" )
        err "$name failed. Run the script again to retry it."
    fi
}

# install_each <install_formula|install_cask> <name...>: fails if any install failed
install_each() {
    local installer="$1" name; shift
    local -i failed=0 i=0
    for name in "$@"; do
        progress "$name" $(( i++ )) $#
        [[ "$name" == "agkozak-zsh-prompt" ]] && continue   # cloned with git, not a formula
        "$installer" "$name" || failed=1
    done
    return $failed
}

# ============ INSTALL STEPS ============
install_homebrew() {
    if [[ -x /opt/homebrew/bin/brew ]]; then
        ok "Found homebrew installation"
        return 0
    fi
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || { err "Homebrew installation failed."; return 1; }
}

# Runs every time: puts brew on PATH and taps the repositories, since the last run may have untapped them
setup_brew() {
    [[ -x /opt/homebrew/bin/brew ]] || return 1
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Homebrew asks for confirmation before installs with dependencies unless this is set
    export HOMEBREW_NO_ASK=1
    local tap
    for tap in "${TAPS[@]}"; do brew tap "$tap" || return 1; done
    # Homebrew refuses to load formulae from non-official taps until they are trusted
    brew trust --tap "${TAPS[@]}"
}

install_rosetta() {
    if is_installed "Rosetta 2"; then
        warn "Rosetta 2 is already installed"
        return 0
    fi
    softwareupdate --install-rosetta --agree-to-license
}

install_kisj_apps() {
    local -i failed=0
    install_formula "mas" || return 1
    mas install 1645016851 || failed=1 # Bluebook
    mas install 1496582158 || failed=1 # Exam.net
    mas install 6450684725 || failed=1 # NWEA
    return $failed
}

# Services print their own errors and can be restarted by hand, so they never block recovery
start_services() {
    if in_array "skhd" "${formulae[@]}"; then
        skhd --start-service
    fi
    if in_array "borders" "${formulae[@]}"; then
        brew services start borders
    fi
    if in_array "sketchybar" "${formulae[@]}"; then
        brew services start sketchybar
    fi
    if in_array "yabai" "${formulae[@]}"; then
        info "Configuring yabai scripting additions..."
        echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai

        yabai --start-service

        note "Make sure to disable csrutil partially: csrutil enable --without fs --without debug --without nvram"
    fi
    return 0
}

untap_unused() {
    local tap
    for tap in "${TAPS[@]}"; do
        # Homebrew refuses while formulae from the tap are installed (--force would uninstall them)
        if brew untap "$tap" >/dev/null 2>&1; then
            ok "Untapped $tap"
        else
            info "Kept $tap because installed formulae come from it"
        fi
    done
}

# Every step in order. run_installers walks this twice: once to count the steps, once to run them,
# so it may only call step and check selections.
install_sequence() {
    step "Install Homebrew" install_homebrew
    step -a "Set up Homebrew" setup_brew
    step "Install git and stow" install_each install_formula git stow
    step "Install formulae" install_each install_formula "${formulae[@]}"
    # Some casks need Rosetta, so install it first
    in_array "Rosetta 2" "${nonbrew[@]}" && step "Install Rosetta 2" install_rosetta
    step "Install casks" install_each install_cask "${casks[@]}"

    in_array "Minimalist" "${nonbrew[@]}" && step "Apply Minimalist preset" minimalist
    in_array "No Animations" "${nonbrew[@]}" && step "Apply No Animations preset" noanimation
    in_array "Revamped Finder" "${nonbrew[@]}" && step "Apply Revamped Finder preset" fixfinder
    in_array "QoL" "${nonbrew[@]}" && step "Apply Quality of Life preset" qol
    # Last, so these win over the menu bar and key repeat values of the presets above
    in_array "sbrothers7 Settings" "${nonbrew[@]}" && step "Apply sbrothers7 Settings preset" personal
    in_array "KISJ App Bundle" "${nonbrew[@]}" && step "Install KISJ apps" install_kisj_apps

    # "Don't use dotfiles" leaves the repo and any existing links alone
    (( DOTFILES_MODE != 3 )) && step "Download dotfiles" get_dotfiles
    step "Generate ~/.zshrc.local" write_zshrc
    (( DOTFILES_MODE != 3 )) && step "Link dotfiles" stow_dotfiles
    step -a "Load ~/.zshrc.local from ~/.zshrc" hook_zshrc
    step "Start services" start_services

    # Only after everything else worked, since a resumed run still needs the taps
    (( ${#FAILED_STEPS} )) || step -a "Untap formula repositories" untap_unused
}

run_installers() {
    clear
    gather_pkgs
    if in_array "Fonts" "${nonbrew[@]}"; then
        casks+=( "${FONT_CASKS[@]}" )
    fi

    COUNT_ONLY=1; install_sequence; COUNT_ONLY=0

    if (( USE_OVERLAY )); then
        mkdir -p "${INSTALL_LOG:h}"
        overlay_start
        install_sequence </dev/null >"$INSTALL_LOG" 2>&1
        overlay_stop
    else
        install_sequence
    fi

    print
    local text
    for text in "${NOTES[@]}"; do warn "$text"; done
    (( USE_OVERLAY )) && info "Full log: $INSTALL_LOG"
    if (( ${#FAILED_STEPS} )); then
        err "Failed: ${(j:, :)FAILED_STEPS}"
        warn "Run the script again and choose Resume to retry only those."
        exit 1
    fi
    rm -f "$PROGRESS_FILE"
    ok "All done!"
}

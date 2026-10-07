# Steps, resume and the install run shared by every platform.
# The platform files provide gather_pkgs and install_sequence.

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

# ============ RUN ============
run_installers() {
    clear
    gather_pkgs

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

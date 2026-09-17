#!/usr/bin/env zsh

# The installer lives in install/ next to this file. When this file is run straight from curl,
# those files aren't on disk, so the repo is downloaded to a temporary folder first.
LIB_DIR="${0:A:h}/install"
if [[ ! -f "$LIB_DIR/config.zsh" ]]; then
    DOWNLOAD_DIR="$(mktemp -d)"
    curl -fsSL https://github.com/sbrothers7/dotfiles/archive/refs/heads/main.tar.gz | tar -xzf - -C "$DOWNLOAD_DIR"
    LIB_DIR="$DOWNLOAD_DIR/dotfiles-main/install"
fi
for part in config ui selection presets dotfiles overlay steps; do
    source "$LIB_DIR/$part.zsh" || { print "Could not load installer file $part.zsh"; exit 1; }
done
# --test: everything runs except the install steps, which are faked (see install/test.zsh)
[[ "$1" == --test ]] && source "$LIB_DIR/test.zsh"

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

if (( ! TEST_MODE )); then
    info "This script needs sudo privileges during install."
    sudo -v || { err "sudo required"; exit 1; }
    # Homebrew resets the sudo timestamp on every brew call, so casks would ask for the password again.
    # Allow passwordless sudo only while this script runs.
    print -r -- "$(id -un) ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_TMP" >/dev/null && sudo chmod 440 "$SUDOERS_TMP"
fi
trap 'tui_stop; overlay_stop; [[ -f "$SUDOERS_TMP" ]] && sudo rm -f "$SUDOERS_TMP"; [[ -n "$DOWNLOAD_DIR" ]] && rm -rf "$DOWNLOAD_DIR"' EXIT
trap 'exit 130' INT TERM HUP

clear
info "Checking compatibility issues..."
compat

info "Initializing..."
init
if [[ -f "$STATE_FILE" ]]; then
    source "$STATE_FILE"
    ok "Restored selections from the last run"
fi
find_installed
ok "Script ready"
print -n -- "Press any key to start"
read -k
clear

# A progress file is only left behind when an install stopped before finishing
if [[ -f "$PROGRESS_FILE" ]]; then
    tui_start
    ui_choose "Resume unfinished install?" "Resume where it stopped" "Start over"
    tui_stop
    if (( UI_CUR == 1 )); then
        run_installers
        exit 0
    fi
fi

main_loop

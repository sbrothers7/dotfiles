# ============ TEST MODE (Arch Linux) ============
# Loaded by `install.sh --test`: the real menus, loading screen, resume and summary, with every install step faked.
# Nothing is installed or changed, and state lives in its own folder so a real unfinished install stays untouched.
# TEST_FAIL=<menu item> makes that item's fake install fail, to try the failure summary and Resume.

TEST_MODE=1
TITLE="Installation Setup (Arch Linux, test mode)"
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

install_item() {
    [[ -n "${INSTALLED[$1]}" ]] && { warn "$1 already installed"; return 0; }
    local -a pkgs=( $(pkgs_of "$1") )
    [[ "$1" == "$TEST_FAIL" ]] && { fake 1 "resolving dependencies..." "error: target not found: ${pkgs[1]} (test failure)"; return 1; }
    fake 1.5 "resolving dependencies..." "Packages (${#pkgs}) ${pkgs[*]}" \
        ":: Proceed with installation? [Y/n]" "(${#pkgs}/${#pkgs}) installing ${pkgs[-1]}"
}

update_system()    { fake 2 ":: Synchronizing package databases..." ":: Starting full system upgrade..." " there is nothing to do"; }
install_yay()      { command -v yay >/dev/null && { ok "Found yay installation"; return 0; }; fake 3 "Cloning into 'yay-bin'..." "==> Making package: yay-bin" "==> Finished making: yay-bin"; }
enable_multilib()  { fake 1 "Enabling [multilib] in /etc/pacman.conf" ":: Synchronizing package databases..."; }
enable_services()  { local item; for item in "${picked_System[@]}"; do fake 0.3 "Enabling services for $item"; done; }
setup_zram()       { fake 0.5 "Writing /etc/systemd/zram-generator.conf"; }
set_shell()        { fake 0.5 "Changing shell for $(id -un)." "Shell changed."; }
install_minegrub() { fake 2 "Cloning into 'minegrub-theme'..." "Copying theme to /boot/grub/themes" "Generating grub configuration file ..." "done"; }
get_dotfiles()     { fake 2 "Cloning into '$DOTS_DIR'..." "Resolving deltas: 100% done."; }
hook_zshrc()       { fake 0.3 "Writing ~/.zshrc.local and loading it from ~/.zshrc"; }

# Shows which dotfiles the real step would link
stow_dotfiles() {
    local -a picked_dots
    local -i i
    local name
    for (( i = 1; i <= ${#CATEGORY_Dotfiles}; i++ )); do
        [[ "${selected_Dotfiles[i]}" == 1 ]] && picked_dots+=( "${CATEGORY_Dotfiles[i]}" )
    done
    for name in "${CATEGORY_Dotfiles[@]}"; do
        dotfile_needed "$name" "${picked_dots[@]}" && fake 0.2 "LINK: $name"
    done
    return 0
}

# Anything not faked above still can't touch this system
for cmd in sudo yay makepkg systemctl chsh stow git grub-mkconfig; do
    functions[$cmd]="print -r -- \"(test mode) skipped: $cmd \$*\""
done
unset cmd

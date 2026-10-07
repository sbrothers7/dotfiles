# Arch Linux install steps and the full install sequence

# yay installs repo and AUR packages alike; --needed skips what is already there
YAY_FLAGS=( --needed --noconfirm --answerclean None --answerdiff None --removemake )

# install_item <menu item>: install every package behind it
install_item() {
    local item="$1"
    local -a pkgs=( $(pkgs_of "$item") )
    local kernel
    # DKMS needs the headers of each installed kernel
    if [[ "$item" == NVIDIA ]]; then
        for kernel in linux linux-lts linux-zen linux-hardened; do
            pacman -Q "$kernel" >/dev/null 2>&1 && pkgs+=( "$kernel-headers" )
        done
    fi
    yay -S "${YAY_FLAGS[@]}" "${pkgs[@]}"
}

# ============ INSTALL STEPS ============
update_system() {
    sudo pacman -Syu --needed --noconfirm base-devel git stow
}

install_yay() {
    if command -v yay >/dev/null; then
        ok "Found yay installation"
        return 0
    fi
    local dir; dir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$dir/yay-bin" \
        && ( cd "$dir/yay-bin" && makepkg -si --noconfirm )
    local -i result=$?
    rm -rf "$dir"
    return $result
}

enable_multilib() {
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        ok "multilib is already enabled"
        return 0
    fi
    # Uncomment the [multilib] header and the Include line below it
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf && sudo pacman -Sy --noconfirm
}

# Enabled only, not started: starting SDDM or NetworkManager mid-install would take over the session or the network
enable_services() {
    local -i failed=0
    local -A units=(
        Bluetooth "bluetooth.service"
        NetworkManager "NetworkManager.service"
        Printing "cups.service avahi-daemon.service"
        SDDM "sddm.service"
    )
    local item unit
    for item in "${picked_System[@]}"; do
        for unit in ${(z)units[$item]}; do
            sudo systemctl enable "$unit" || failed=1
        done
    done
    in_array SDDM "${picked_System[@]}" && note "SDDM starts on the next boot."
    in_array NetworkManager "${picked_System[@]}" \
        && note "NetworkManager starts on the next boot. Disable any other network manager (systemd-networkd, iwd) first."
    in_array NVIDIA "${picked_System[@]}" && note "Reboot to load the NVIDIA driver."
    return $failed
}

setup_zram() {
    if [[ -f /etc/systemd/zram-generator.conf ]]; then
        ok "zram is already configured"
        return 0
    fi
    print -r -- $'[zram0]\nzram-size = min(ram / 2, 4096)\ncompression-algorithm = zstd' \
        | sudo tee /etc/systemd/zram-generator.conf >/dev/null
    note "zram swap starts on the next boot."
}

set_shell() {
    [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" == */zsh ]] && { ok "zsh is already the login shell"; return 0; }
    sudo chsh -s /usr/bin/zsh "$(id -un)" && note "zsh is the login shell from the next login."
}

install_minegrub() {
    if [[ ! -d /boot/grub ]]; then
        err "No /boot/grub found. The minegrub theme needs GRUB."
        return 1
    fi
    local dir; dir="$(mktemp -d)"
    git clone --depth 1 https://github.com/Lxtharia/minegrub-theme.git "$dir/minegrub-theme" || { rm -rf "$dir"; return 1; }
    sudo mkdir -p /boot/grub/themes && sudo cp -r "$dir/minegrub-theme/minegrub" /boot/grub/themes/
    rm -rf "$dir"
    if grep -q '^#\?GRUB_THEME=' /etc/default/grub; then
        sudo sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME=/boot/grub/themes/minegrub/theme.txt|' /etc/default/grub
    else
        print -r -- 'GRUB_THEME=/boot/grub/themes/minegrub/theme.txt' | sudo tee -a /etc/default/grub >/dev/null
    fi
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}

# Every step in order. run_installers walks this twice: once to count the steps, once to run them,
# so it may only call step and check selections.
install_sequence() {
    local cat
    local -a items multilib=( ${picked:*MULTILIB_ITEMS} )

    step "Update system and install base tools" update_system
    step "Install yay" install_yay
    (( ${#multilib} )) && step "Enable multilib repository" enable_multilib
    for cat in "${SUBCATS[@]}"; do
        items=( "${(@P)${:-picked_$cat}}" )
        items=( ${items:|NON_PACKAGES} )
        (( ${#items} )) && step "Install ${(L)cat}" install_each install_item "${items[@]}"
    done

    (( ${#picked_System} )) && step "Enable services" enable_services
    in_array zram "${picked[@]}" && step "Set up zram" setup_zram
    in_array "minegrub theme" "${picked[@]}" && step "Install minegrub theme" install_minegrub
    in_array zsh "${picked[@]}" && step "Make zsh the login shell" set_shell

    # "Don't use dotfiles" leaves the repo and any existing links alone
    if (( DOTFILES_MODE != 3 )); then
        step "Download dotfiles" get_dotfiles
        step "Link dotfiles" stow_dotfiles
    else
        step -a "Load zsh plugins from ~/.zshrc" hook_zshrc
    fi
}

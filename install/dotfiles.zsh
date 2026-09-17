# ============ DOTFILES ============
# Download, ~/.zshrc.local and linking with stow

get_dotfiles() {
    if [[ -d "$DOTS_DIR/.git" ]]; then
        info "Found dotfiles directory. Updating..."
        git -C "$DOTS_DIR" pull --rebase --autostash || warn "Could not update dotfiles, using local copy."
    else
        info "Downloading sbrothers7 dotfiles..."
        git clone "https://github.com/sbrothers7/dotfiles" "$DOTS_DIR" || { err "Could not download dotfiles."; return 1; }
    fi
}

# The tracked .zshrc sources ~/.zshrc.local, so rewriting it on every run never touches the repo.
# Each line checks for its program when the shell starts, so a run with fewer picks never drops a working setup.
write_zshrc() {
    # Kept outside the dotfiles repo, which may not be downloaded
    if in_array "agkozak-zsh-prompt" "${formulae[@]}" && [[ ! -d "$HOME/.local/share/agkozak-zsh-prompt" ]]; then
        git clone https://github.com/agkozak/agkozak-zsh-prompt "$HOME/.local/share/agkozak-zsh-prompt" || return 1
    fi

    cat > "$HOME/.zshrc.local" <<'EOF'
if [[ -x /opt/homebrew/bin/nvim ]]; then
    export EDITOR="nvim"
    export SUDO_EDITOR="$EDITOR"
fi
[[ -x /opt/homebrew/bin/fastfetch ]] && alias ff="fastfetch"
[[ -f /opt/homebrew/etc/profile.d/autojump.sh ]] && source /opt/homebrew/etc/profile.d/autojump.sh

# Prompt: starship wins when both are installed
[[ -f ~/.local/share/agkozak-zsh-prompt/agkozak-zsh-prompt.plugin.zsh ]] && source ~/.local/share/agkozak-zsh-prompt/agkozak-zsh-prompt.plugin.zsh
if [[ -x /opt/homebrew/bin/starship ]]; then
    export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
    eval "$(/opt/homebrew/bin/starship init zsh)"
fi

[[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# zsh-syntax-highlighting must be sourced last
[[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF
}

# The repo .zshrc already loads ~/.zshrc.local; any other ~/.zshrc gets the lines appended once
hook_zshrc() {
    grep -qsF 'brew shellenv' "$HOME/.zshrc" "$HOME/.zprofile" \
        || print -r -- 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zshrc"
    grep -qsF '.zshrc.local' "$HOME/.zshrc" \
        || print -r -- '[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local' >> "$HOME/.zshrc"
}

# dotfile_needed <name> <picked...>
dotfile_needed() {
    local name="$1"; shift
    in_array "$name" "${CATEGORY_Dotfiles[@]}" || return 1
    if (( DOTFILES_MODE == 2 )); then
        in_array "$name" "$@"
    else
        [[ "$name" == zshrc ]] || is_installed "${DOTFILE_PROGRAM[$name]:-$name}"
    fi
}

stow_dotfiles() {
    cd "$DOTS_DIR" || return 1

    # Remove links from earlier runs, including an old ~/.config that pointed into the repo
    stow -D . 2>/dev/null
    if [[ -L "$HOME/.config" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$HOME/.config" "$BACKUP_DIR/.config"
    fi
    # A real ~/.config makes stow link each app folder instead of the whole directory
    mkdir -p "$HOME/.config"

    local -a picked ignores
    local -i i
    for (( i = 1; i <= ${#CATEGORY_Dotfiles}; i++ )); do
        [[ "${selected_Dotfiles[i]}" == 1 ]] && picked+=( "${CATEGORY_Dotfiles[i]}" )
    done

    local item name target
    for item in .zshrc .config/*(N); do
        # .zshrc -> zshrc, .config/nvim -> nvim
        name="${${item:t}#.}"
        if ! dotfile_needed "$name" "${picked[@]}"; then
            ignores+=( "--ignore=^${item//./\\.}" )
            continue
        fi

        # Back up anything in the way that is not already ours
        target="$HOME/$item"
        if [[ -e "$target" || -L "$target" ]] && [[ "${target:A}" != "$DOTS_DIR"/* ]]; then
            info "Backing up: $target"
            mkdir -p "$BACKUP_DIR/${item:h}"
            mv "$target" "$BACKUP_DIR/$item"
        fi
    done

    stow "${ignores[@]}" . && ok "Dotfiles linked into $HOME. Open a new terminal to load them."
}

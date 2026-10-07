# ============ DOTFILES (Arch Linux) ============
# Linking the arch/ stow package. get_dotfiles comes from the shared dotfiles.zsh.

# The zsh folder also brings these links in the home folder
ZSH_LINKS=( .zshrc .zprofile .alias )

# For "Don't use dotfiles": the existing ~/.zshrc gets the plugin lines through ~/.zshrc.local
hook_zshrc() {
    cat > "$HOME/.zshrc.local" <<'EOF'
[[ -f /usr/lib/spaceship-prompt/spaceship.zsh ]] && source /usr/lib/spaceship-prompt/spaceship.zsh
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[fzf] )) && source <(fzf --zsh)
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# zsh-syntax-highlighting must be sourced last
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF
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
        pacman -Q "${DOTFILE_PROGRAM[$name]:-$name}" >/dev/null 2>&1
    fi
}

stow_dotfiles() {
    local pkg_dir="$DOTS_DIR/$STOW_PACKAGE"
    [[ -d "$pkg_dir" ]] || { err "No $STOW_PACKAGE folder in $DOTS_DIR"; return 1; }

    # Remove links from earlier runs
    stow -d "$DOTS_DIR" -t "$HOME" -D "$STOW_PACKAGE" 2>/dev/null
    # Real folders make stow link each app folder or script instead of the whole directory
    mkdir -p "$HOME/.config" "$HOME/.local/bin"

    local -a picked_dots ignores items
    local -i i
    for (( i = 1; i <= ${#CATEGORY_Dotfiles}; i++ )); do
        [[ "${selected_Dotfiles[i]}" == 1 ]] && picked_dots+=( "${CATEGORY_Dotfiles[i]}" )
    done

    local item name target
    local -i link_zsh=0
    dotfile_needed zsh "${picked_dots[@]}" && link_zsh=1
    for item in "$pkg_dir"/.config/*(N) "$pkg_dir"/.local/bin/*(N); do items+=( "${item#$pkg_dir/}" ); done
    items+=( "${ZSH_LINKS[@]}" )
    for item in "${items[@]}"; do
        case "$item" in
            .local/bin/*) ;;
            .config/*) dotfile_needed "${item:t}" "${picked_dots[@]}" || { ignores+=( "--ignore=^${item//./\\.}" ); continue; } ;;
            *) (( link_zsh )) || { ignores+=( "--ignore=^${item//./\\.}" ); continue; } ;;
        esac

        # Back up anything in the way that is not already ours
        target="$HOME/$item"
        if [[ -e "$target" || -L "$target" ]] && [[ "${target:A}" != "$DOTS_DIR"/* ]]; then
            info "Backing up: $target"
            mkdir -p "$BACKUP_DIR/${item:h}"
            mv "$target" "$BACKUP_DIR/$item"
        fi
    done

    stow -d "$DOTS_DIR" -t "$HOME" "${ignores[@]}" "$STOW_PACKAGE" \
        && ok "Dotfiles linked into $HOME. Log out and back in to load them."
}

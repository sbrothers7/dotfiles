# Menu selections, the packages they install, and detection of what is already installed

# ============ STATE ============
typeset -a selected_Desktop selected_Shell selected_Utilities selected_Apps selected_System selected_Theming selected_Dotfiles

init() {
    local cat sel_var items_var defs_var d
    local -i i len
    for cat in "${SUBCATS[@]}" Dotfiles; do
        sel_var="selected_${cat}" items_var="CATEGORY_${cat}" defs_var="DEFAULT_${cat}"
        len=${#${(P)items_var}}
        eval "$sel_var=()"
        for (( i = 1; i <= len; i++ )); do eval "${sel_var}[i]=0"; done
        [[ "$1" == clear ]] && continue
        for d in "${(@P)defs_var}"; do
            (( d >= 1 && d <= len )) && eval "${sel_var}[d]=1"
        done
    done
}

# picked_<cat>: the selected items of each category, and picked: all of them
gather_pkgs() {
    local cat sel_var items_var
    local -i i
    typeset -ga picked=()
    for cat in "${SUBCATS[@]}"; do
        sel_var="selected_${cat}" items_var="CATEGORY_${cat}"
        typeset -ga "picked_${cat}"
        eval "picked_${cat}=()"
        for (( i = 1; i <= ${#${(P)items_var}}; i++ )); do
            if [[ "${${(P)sel_var}[i]}" == 1 ]]; then
                eval 'picked_'"$cat"'+=( "${'"$items_var"'[i]}" )'
                picked+=( "${${(P)items_var}[i]}" )
            fi
        done
    done
}

in_array() {
    local index="$1"; shift
    local -a arr=( "$@" )

    (( ${arr[(Ie)$index]} ))
}

# pkgs_of <menu item>: its packages, one per line
pkgs_of() {
    print -rl -- ${(z)PKGS[$1]:-$1}
}

# is_installed <menu item or package>: whether it is already on this system
is_installed() {
    local name="$1"
    case "$name" in
        "") return 1 ;;
        "minegrub theme") [[ -f /boot/grub/themes/minegrub/theme.txt ]] ;;
        *) pacman -Q $(pkgs_of "$name") >/dev/null 2>&1 ;;
    esac
}

# Filled once at startup so the menu can grey out what is already installed
typeset -gA INSTALLED
find_installed() {
    local cat item
    for cat in "${SUBCATS[@]}"; do
        for item in "${(@P)${:-CATEGORY_$cat}}"; do
            is_installed "$item" && INSTALLED[$item]=1
        done
    done
}

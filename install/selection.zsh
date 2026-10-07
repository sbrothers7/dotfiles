# Menu selections, what they install, and detection of what is already installed

# ============ STATE ============
typeset -a selected_WM selected_ZSH selected_Utilities selected_Casks selected_Defaults selected_Other selected_Dotfiles

init() {
    for cat in "${SUBCATS[@]}" Dotfiles; do
        sel_var="selected_${cat}"
        items_var="CATEGORY_${cat}"
        defs_var="DEFAULT_${cat}"

        eval "$sel_var=()"
        eval "len=\${#${items_var}[@]}"
        for ((i=1; i<=len; i++)); do eval "${sel_var}[$i]=0"; done
        [[ "$1" == clear ]] && continue
        eval 'for d in "${'"$defs_var"'[@]}"; do
                  (( d>=1 && d<=len )) && '"${sel_var}"'[$d]=1
              done'
    done
}

gather_pkgs() {
    typeset -ga formulae=() casks=() nonbrew=()
    local i cat j items_var sel_var len s

    for i in {1..${#SUBCATS[@]}}; do
        cat="${SUBCATS[$i]}"

        items_var="CATEGORY_${cat}"
        sel_var="selected_${cat}"

        eval "len=\${#${items_var}[@]}"
        for (( j=1; j<=len; j++ )); do
            eval 's="${'"$sel_var"'[$j]}"'
            if [[ "$s" == 1 ]]; then
                if (( i == 4 )); then
                    eval 'casks+=( "${'"$items_var"'[$j]}" )'
                elif (( i > 4 )); then
                    eval 'nonbrew+=( "${'"$items_var"'[$j]}" )' # non brew-related
                else
                    eval 'formulae+=( "${'"$items_var"'[$j]}" )'
                fi
            fi
        done
    done
    
    in_array "Fonts" "${nonbrew[@]}" && casks+=( "${FONT_CASKS[@]}" )

    # Deduplicate in zsh
    typeset -gaU formulae=("${formulae[@]}")
    typeset -gaU casks=("${casks[@]}")
    
    # echo "${formulae[@]}"
    # echo "${casks[@]}"
    # echo "${nonbrew[@]}"
}

in_array() {
    local index="$1"; shift
    local -a arr=( "$@" )

    (( ${arr[(Ie)$index]} ))
}

# is_installed <menu item or program>: whether it is already on this Mac
is_installed() {
    local name="$1" font
    local -a versioned
    case "$name" in
        "") return 1 ;;
        agkozak-zsh-prompt) [[ -d "$HOME/.local/share/agkozak-zsh-prompt" ]] ;;
        "Rosetta 2") [[ -f /Library/Apple/usr/libexec/oah/libRosettaRuntime ]] ;;
        Fonts)
            for font in "${FONT_CASKS[@]}"; do [[ -d "/opt/homebrew/Caskroom/$font" ]] || return 1; done
            ;;
        *)
            # Formulae like python install as python@3.x
            versioned=( /opt/homebrew/Cellar/$name@*(N) )
            [[ -d "/opt/homebrew/Cellar/$name" || -d "/opt/homebrew/Caskroom/$name" ]] || (( ${#versioned} ))
            ;;
    esac
}

# Filled once at startup so the menu can grey out what is already installed
typeset -gA INSTALLED
find_installed() {
    local cat item
    for cat in "${SUBCATS[@]}"; do
        eval 'for item in "${CATEGORY_'"$cat"'[@]}"; do is_installed "$item" && INSTALLED[$item]=1; done'
    done
}

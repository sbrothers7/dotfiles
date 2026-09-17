# Terminal output helpers, full-screen menu widgets and the main menu

ok()    { print -P "%B%F{green}✔ $*%f%b"; }
warn()  { print -P "%F{yellow}$*%f"; }
err()   { print -P "%B%F{red}✖ $*%f%b"; }
info()  { print -P "%B%F{blue}$*%f%b"; }
# note <text>: a warning that is repeated after the install, since the loading screen hides the log
note()  { warn "$*"; NOTES+=( "$*" ); }
dim()   { print -P "%F{black}$*%f"; }

# ============ TUI ============
# Full-screen menus drawn with escape codes, so they work before anything is installed
typeset -gi UI_ON=0 UI_CUR=1 UI_TOP=0

tui_start() { UI_ON=1; stty -echo; print -rn -- $'\e[?1049h\e[?25l'; }
tui_stop()  { (( UI_ON )) || return 0; UI_ON=0; stty echo; print -rn -- $'\e[?25h\e[?1049l'; }

read_key() {
    # One keystroke into REPLY; arrow keys arrive as a 3-byte escape sequence
    local rest
    IFS= read -rsk1 REPLY
    if [[ "$REPLY" == $'\e' ]]; then
        IFS= read -rsk2 -t 0.05 rest
        REPLY+=$rest
    fi
}

is_enter() { [[ "$1" == $'\n' || "$1" == $'\r' ]]; }

# ui_draw <title> <hints> <row...>   (hints: one key per line)
# Centered box with row UI_CUR highlighted and scrolled into view. Empty rows are spacers;
# rows starting with a tab are greyed out and rows starting with \x01 are green.
ui_draw() {
    local title=$1 hint=$2; shift 2
    local -a rows=( "$@" ) hints=( "${(@f)hint}" ) size=( $(stty size </dev/tty) )
    local -i H=${size[1]} W=${size[2]} iw=${#title}+2 vis i n
    local r style E=$'\e'
    local B="${E}[34m" R="${E}[0m"

    for r in "${rows[@]}"; do r="${${r#$'\t'}#$'\x01'}"; (( ${#r} > iw )) && iw=${#r}; done
    (( iw > W - 6 )) && iw=W-6
    vis=$(( ${#rows} < H - 5 - ${#hints} ? ${#rows} : H - 5 - ${#hints} ))
    (( UI_CUR <= UI_TOP )) && UI_TOP=UI_CUR-1
    (( UI_CUR > UI_TOP + vis )) && UI_TOP=UI_CUR-vis
    (( UI_TOP > ${#rows} - vis )) && UI_TOP=${#rows}-vis
    (( UI_TOP < 0 )) && UI_TOP=0

    local -i y=$(( (H - vis - 2 - ${#hints}) / 2 + 1 )) x=$(( (W - iw - 4) / 2 + 1 ))
    # Wrapped in a synchronized update so terminals that support it redraw without flicker
    local out="${E}[?2026h${E}[H${E}[2J${E}[${y};${x}H$B┌─ $R${E}[1m$title$R$B ${(l:iw-${#title}-1::─:):-}┐$R"
    for (( i = 1; i <= vis; i++ )); do
        n=UI_TOP+i
        r="${rows[n]}" style=""
        [[ "$r" == $'\t'* ]] && { r="${r#$'\t'}"; style="${E}[2m"; }
        [[ "$r" == $'\x01'* ]] && { r="${r#$'\x01'}"; style="${E}[32m"; }
        r=" ${(r:iw:)r} "
        (( n == UI_CUR )) && style+="${E}[7m"
        [[ -n "$style" ]] && r="$style$r$R"
        out+="${E}[$((y+i));${x}H$B│$R$r$B│$R"
    done
    r=""; (( UI_TOP + vis < ${#rows} )) && r=" more ↓ "
    out+="${E}[$((y+vis+1));${x}H$B└${(l:iw+2-${#r}::─:):-}$r┘$R"
    for (( i = 1; i <= ${#hints}; i++ )); do
        out+="${E}[$((y+vis+1+i));${x}H${E}[2m${hints[i]}$R"
    done
    print -rn -- "$out${E}[?2026l"
}

# ui_list <title> <hints> <row...>
# Moves UI_CUR with arrows or j/k and returns on any other key, which is left in REPLY
ui_list() {
    local title=$1 hint=$2; shift 2
    local -i d c
    while true; do
        ui_draw "$title" "$hint" "$@"
        read_key
        case "$REPLY" in
            $'\e[A'|k) d=-1 ;;
            $'\e[B'|j) d=1 ;;
            *) return 0 ;;
        esac
        c=UI_CUR+d
        while (( c >= 1 && c <= $# )) && [[ -z "${@[c]}" ]]; do (( c += d )); done
        (( c >= 1 && c <= $# )) && UI_CUR=c
    done
}

# Checkbox list for one category, toggling selected_<cat> in place
ui_checklist() {
    local -r cat="$1"
    local -a items rows; eval "items=( \"\${CATEGORY_${cat}[@]}\" )"
    local -i i v w=0
    local item
    for item in "${items[@]}"; do (( ${#item} > w )) && w=${#item}; done
    UI_CUR=1 UI_TOP=0
    while true; do
        rows=()
        for (( i = 1; i <= ${#items}; i++ )); do
            if [[ "$cat" != Dotfiles && -n "${INSTALLED[${items[i]}]}" ]]; then
                rows+=( $'\t'"[✓] ${(r:w:)items[i]}  installed" )
            elif eval "[[ \${selected_${cat}[i]} == 1 ]]"; then
                rows+=( "[x] ${items[i]}" )
            else
                rows+=( "[ ] ${items[i]}" )
            fi
        done
        ui_list "$cat" $'↑↓      move\nspace   toggle\na       select all\nn       select none\nenter   back' "${rows[@]}"
        case "$REPLY" in
            ' ') [[ "${rows[UI_CUR]}" == $'\t'* ]] || eval "(( selected_${cat}[UI_CUR] = !selected_${cat}[UI_CUR] ))" ;;
            a|n)
                v=0; [[ "$REPLY" == a ]] && v=1
                for (( i = 1; i <= ${#items}; i++ )); do
                    [[ "${rows[i]}" == $'\t'* ]] || eval "selected_${cat}[i]=$v"
                done
                ;;
            $'\n'|$'\r'|$'\e'|$'\e[D'|q|h) return 0 ;;
        esac
    done
}

# ui_choose <title> <option...>: dialog that sets UI_CUR to the chosen option, or 0 on esc
ui_choose() {
    local title="$1"; shift
    UI_CUR=1 UI_TOP=0
    while true; do
        ui_list "$title" $'↑↓      move\nenter   choose\nesc     back' "$@"
        is_enter "$REPLY" && return 0
        [[ "$REPLY" == $'\e' ]] && { UI_CUR=0; return 0; }
    done
}

# =============== MAIN LOOP ===============
main_loop() {
    local -a rows items sel picked
    local -a onoff=( off on )
    local -i main_cur=1 i
    local cat
    tui_start
    while true; do
        # One row per category with its current picks, then actions
        rows=()
        for cat in "${SUBCATS[@]}"; do
            eval "items=( \"\${CATEGORY_${cat}[@]}\" ); sel=( \"\${selected_${cat}[@]}\" )"
            picked=()
            for (( i = 1; i <= ${#items}; i++ )); do
                # Installed programs can't be picked
                if [[ -n "${INSTALLED[${items[i]}]}" ]]; then
                    eval "selected_${cat}[i]=0"
                elif [[ "${sel[i]}" == 1 ]]; then
                    picked+=( "${items[i]}" )
                fi
            done
            rows+=( "${(r:16:)${:-$cat (${#picked})}}${(j:, :)picked:-none}" )
        done
        rows+=( "" "Install" "Loading screen: ${onoff[USE_OVERLAY + 1]}" "Clear all" "Reset to defaults" "Quit" )

        UI_CUR=main_cur UI_TOP=0
        ui_list "$TITLE" $'↑↓      move\nenter   open\nq       quit' "${rows[@]}"
        main_cur=UI_CUR
        [[ "$REPLY" == q ]] && exit 0
        is_enter "$REPLY" || [[ "$REPLY" == ' ' || "$REPLY" == $'\e[C' ]] || continue

        case "${rows[UI_CUR]}" in
            Install) confirm_install ;;
            "Clear all") init clear ;;
            "Loading screen: "*) (( USE_OVERLAY = !USE_OVERLAY )) ;;
            "Reset to defaults") init ;;
            Quit) exit 0 ;;
            *) ui_checklist "${SUBCATS[UI_CUR]}" ;;
        esac
    done
}

confirm_install() {
    ui_choose "Dotfiles" "Use dotfiles" "Select programs to use dotfiles" "Don't use dotfiles"
    (( UI_CUR )) || return 0
    DOTFILES_MODE=UI_CUR
    (( DOTFILES_MODE == 2 )) && ui_checklist Dotfiles

    ui_choose "Start installation?" "Yes, install now" "No, go back"
    (( UI_CUR == 1 )) || return 0

    # Saved so an interrupted install can be resumed with the same selections
    mkdir -p "${STATE_FILE:h}"
    typeset -p selected_WM selected_ZSH selected_Utilities selected_Casks selected_Defaults selected_Other selected_Dotfiles DOTFILES_MODE USE_OVERLAY > "$STATE_FILE"
    : > "$PROGRESS_FILE"

    tui_stop
    run_installers
    exit 0
}

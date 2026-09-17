# ============ LOADING SCREEN ============
# While installing, output goes to INSTALL_LOG and a background process draws a progress screen.
# Steps report what they are doing through a small status file; pressing l switches to the raw log.

typeset -g OVERLAY_DIR="" OVERLAY_PID=""

# progress <what> [done total]: tell the loading screen what is being installed right now
progress() {
    [[ -n "$OVERLAY_DIR" ]] || return 0
    print -rl -- "$STEP_INDEX" "$STEP_TOTAL" "$STEP_NAME" "$1" "${2:-0}" "${3:-0}" > "$OVERLAY_DIR/status.new"
    mv -f "$OVERLAY_DIR/status.new" "$OVERLAY_DIR/status"
}

overlay_start() {
    OVERLAY_DIR="$(mktemp -d)"
    : > "$OVERLAY_DIR/running"
    progress ""
    overlay_loop &
    OVERLAY_PID=$!
}

overlay_stop() {
    [[ -n "$OVERLAY_PID" ]] || return 0
    # The loop checks this file between frames, so it never stops halfway through drawing
    rm -f "$OVERLAY_DIR/running"
    wait "$OVERLAY_PID" 2>/dev/null
    rm -rf "$OVERLAY_DIR"
    OVERLAY_PID="" OVERLAY_DIR=""
}

# overlay_screen <1|0>: switch to the full-screen view or back to the normal terminal
overlay_screen() {
    if (( $1 )); then print -rn -- $'\e[?1049h\e[?25l'; else print -rn -- $'\e[?25h\e[?1049l'; fi > /dev/tty
}

# Runs in the background until overlay_stop, or until the installer is gone.
# Draws straight to the terminal, since stdout is the log.
overlay_loop() {
    setopt localoptions extendedglob
    local -i show=1 printed=0 size tick=0 started=SECONDS idx total done_items items pct filled elapsed
    local -i w=52 bw=44
    local key line item spin frames="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local -a st rows

    # Ctrl-C is handled by the installer, which stops this process
    trap - EXIT
    trap '' INT
    stty -echo </dev/tty
    overlay_screen 1

    UI_CUR=0 UI_TOP=0
    while [[ -f "$OVERLAY_DIR/running" ]] && kill -0 $$ 2>/dev/null; do
        if (( show )); then
            # status file: step index, step count, step name, current item, items done, item count
            st=( "${(@f)$(<"$OVERLAY_DIR/status")}" )
            idx=${st[1]} total=${st[2]} done_items=${st[5]} items=${st[6]}
            pct=0
            (( total )) && pct=$(( ((idx > 0 ? idx - 1 : 0) * 100 + (items ? done_items * 100 / items : 0)) / total ))
            filled=$(( pct * bw / 100 ))
            elapsed=$(( SECONDS - started ))
            spin=${frames[tick % ${#frames} + 1]}
            item="${st[4]}"
            (( items )) && [[ -n "$item" ]] && item+="  ($((done_items + 1)) of $items)"

            # Newest log line without colors or control characters
            line="$(tail -n 1 "$INSTALL_LOG" 2>/dev/null)"
            line="${${line//$'\e'\[[0-9;]#[a-zA-Z]/}//[[:cntrl:]]/}"

            rows=(
                "${(l:w:):-}"
                "  $spin  ${st[3]:-Starting}"
                $'\t'"     $item"
                ""
                $'\x01'"  ${(l:filled::█:):-}${(l:bw-filled::░:):-}  ${(l:3:)pct}%"
                "  Step $idx of $total  ·  $((elapsed / 60)):${(l:2::0:)$((elapsed % 60))}"
                ""
                $'\t'"  ${line[1,w-2]}"
            )
            ui_draw "Installing${TEST_MODE:+ (test mode)}" $'l        show log\nctrl-c   stop' "${rows[@]}" > /dev/tty
        else
            overlay_flush
        fi

        # Waiting for a key also paces the spinner
        if read -rsk1 -t 0.1 key </dev/tty && [[ "$key" == l ]]; then
            (( show = !show ))
            overlay_screen $show
            (( show )) || print -r -- $'\n--- install log (press l for the loading screen) ---' > /dev/tty
        fi
        (( tick++ ))
    done

    if (( show )); then overlay_screen 0; else overlay_flush; fi
    stty echo </dev/tty
}

# Prints whatever the log gained since the last call
overlay_flush() {
    size=$(stat -f %z "$INSTALL_LOG" 2>/dev/null || print 0)
    if (( size > printed )); then
        tail -c +$(( printed + 1 )) "$INSTALL_LOG" | head -c $(( size - printed )) > /dev/tty
        printed=size
    fi
}

#!/usr/bin/env bash
# Give GIMP the hidden shortcuts tablet-pad.json's dials send (tool options have none by default).
# GIMP rewrites shortcutsrc on exit, so this only runs while GIMP is closed. Safe to re-run.
set -euo pipefail

RC=${1:-$HOME/.config/GIMP/3.2/shortcutsrc}
SHORTCUTS=(
    'tools-size-decrease-percent <Primary><Shift><Alt>q'
    'tools-size-increase-percent <Primary><Shift><Alt>w'
    'tools-size-decrease <Primary><Shift><Alt>a'            # -1 px
    'tools-size-increase <Primary><Shift><Alt>s'
    'tools-size-decrease-skip <Primary><Shift><Alt>c'       # -10 px
    'tools-size-increase-skip <Primary><Shift><Alt>v'
    'tools-hardness-decrease <Primary><Shift><Alt>z'
    'tools-hardness-increase <Primary><Shift><Alt>x'
    'tools-angle-decrease <Primary><Shift><Alt>e'
    'tools-angle-increase <Primary><Shift><Alt>r'
    'view-zoom-out <Primary><Shift><Alt>d minus KP_Subtract ZoomOut'   # keeps GIMP's default keys
    'view-zoom-in <Primary><Shift><Alt>f plus KP_Add ZoomIn'
)

if pgrep -x 'gimp(-[0-9.]+)?' >/dev/null; then
    echo "GIMP is running; close it first (it would overwrite the change on exit)." >&2
    exit 1
fi
[[ -f $RC ]] || { echo "no $RC (start GIMP once first)" >&2; exit 1; }

cp "$RC" "$RC.bak"
for s in "${SHORTCUTS[@]}"; do
    action=${s%% *} accels=\"${s#* }\"
    accels=${accels// /\" \"}
    # keep keys the action already has (e.g. a custom zoom key), then drop that binding
    old=$(sed -n "s/^(action \"$action\" \(.*\))$/\1/p" "$RC")
    for a in $old; do [[ " $accels " == *" $a "* ]] || accels+=" $a"; done
    # add ours before the end marker
    sed -i "/^(action \"$action\" /d; /^(action \"$action\")$/d; /^# (action \"$action\"[ )]/d" "$RC"
    sed -i "s|^# end of shortcutsrc|(action \"$action\" $accels)\n&|" "$RC"
done
echo "added ${#SHORTCUTS[@]} shortcuts to $RC (backup: $RC.bak)"

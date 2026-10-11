#!/usr/bin/env bash
# Keep in sync with input.repeat_rate / repeat_delay in hyprland.lua
NORMAL_RATE=45
NORMAL_DELAY=200
TARGET_CLASSES=("Minecraft" "ADanceOfFireAndIce" "steam_app_960170")  # Add more classes as needed

set_repeat() {
  hyprctl eval "hl.config({ input = { repeat_rate = $1, repeat_delay = $2 } })" >/dev/null
}

state=""

socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
  while read -r line; do
    if [[ "$line" == activewindowv2* ]]; then
      CLASS=$(hyprctl activewindow -j | jq -r '.class')

      # Check if CLASS matches any of the TARGET_CLASSES
      new_state=normal
      for target in "${TARGET_CLASSES[@]}"; do
        if [[ "$CLASS" == *"$target"* ]]; then
          new_state=game
          break
        fi
      done

      [[ "$new_state" == "$state" ]] && continue
      state=$new_state

      if [[ "$state" == game ]]; then
        set_repeat 0 10000
      else
        set_repeat "$NORMAL_RATE" "$NORMAL_DELAY"
      fi
    fi
  done

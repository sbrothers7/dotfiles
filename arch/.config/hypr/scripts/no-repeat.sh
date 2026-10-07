#!/usr/bin/env bash
NORMAL_RATE=25
NORMAL_DELAY=600
TARGET_CLASSES=("Minecraft" "ADanceOfFireAndIce" "steam_app_960170")  # Add more classes as needed

socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
  while read -r line; do
    if [[ "$line" == activewindowv2* ]]; then
      CLASS=$(hyprctl activewindow -j | jq -r '.class')
      
      # Check if CLASS matches any of the TARGET_CLASSES
      matched=false
      for target in "${TARGET_CLASSES[@]}"; do
        if [[ "$CLASS" == *"$target"* ]]; then
          matched=true
          break
        fi
      done
      
      if [[ "$matched" == true ]]; then
        hyprctl keyword input:repeat_rate 0
        hyprctl keyword input:repeat_delay 10000
      else
        hyprctl keyword input:repeat_rate "$NORMAL_RATE"
        hyprctl keyword input:repeat_delay "$NORMAL_DELAY"
      fi
    fi
  done

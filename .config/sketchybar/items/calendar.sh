#!/bin/bash

sketchybar --add item calendar right \
  --set calendar icon=􀧞 \
  set calendar padding_right=10\
  update_freq=15 \
  script="$PLUGIN_DIR/calendar.sh"

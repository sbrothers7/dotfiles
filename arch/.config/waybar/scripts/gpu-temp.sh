#!/usr/bin/env bash

# GPU temperature script for Waybar
# Tries NVIDIA first, then AMD/Intel hwmon fallback

# NVIDIA
if command -v nvidia-smi >/dev/null 2>&1; then
    temp="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)"
    if [[ "$temp" =~ ^[0-9]+$ ]]; then
        echo "GPU ${temp}°"
        exit 0
    fi
fi

# AMD / Intel fallback via hwmon
for file in /sys/class/hwmon/hwmon*/temp1_input; do
    [[ -f "$file" ]] || continue
    name_file="$(dirname "$file")/name"
    name="$(cat "$name_file" 2>/dev/null)"

    case "$name" in
        amdgpu|radeon|i915|xe)
            temp_raw="$(cat "$file" 2>/dev/null)"
            if [[ "$temp_raw" =~ ^[0-9]+$ ]]; then
                echo "GPU $((temp_raw / 1000))°"
                exit 0
            fi
            ;;
    esac
done

echo "GPU --"

#!/usr/bin/env bash

# Sketchybar date plugin with calendar popup on hover

FONT="Iosevka Nerd Font Mono"

# Handle hover events for popup
if [[ "$SENDER" == "mouse.entered" ]]; then
    sketchybar --set "$NAME" popup.drawing=on
    exit 0
elif [[ "$SENDER" == "mouse.exited" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
fi

sketchybar --set "$NAME" label="$(date '+%Y/%m/%d')"

# Update calendar popup lines
idx=0
while IFS= read -r line; do
    # Pad short lines to keep monospace alignment
    padded=$(printf '%-20s' "$line")
    sketchybar --set "date.cal${idx}" label="$padded"
    ((idx++))
done < <(cal)

# Hide unused rows
while [[ $idx -lt 8 ]]; do
    sketchybar --set "date.cal${idx}" label=""
    ((idx++))
done

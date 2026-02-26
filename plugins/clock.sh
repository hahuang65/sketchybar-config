#!/usr/bin/env bash

# Sketchybar clock plugin with world clock popup on hover
# Ported from waybar clock module

FONT="Iosevka Nerd Font Mono"

# Handle hover events for popup
if [[ "$SENDER" == "mouse.entered" ]]; then
    sketchybar --set "$NAME" popup.drawing=on
    exit 0
elif [[ "$SENDER" == "mouse.exited" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
fi

local_time=$(date '+%H:%M')
sketchybar --set "$NAME" label="$local_time"

# World clock timezones ordered by UTC offset
timezones=(
    "Honolulu|Pacific/Honolulu"
    "Anchorage|America/Anchorage"
    "Los Angeles|America/Los_Angeles"
    "Denver|America/Denver"
    "LOCAL"
    "New York|America/New_York"
    "Santiago|America/Santiago"
    "London|Europe/London"
    "Berlin|Europe/Berlin"
    "Cairo|Africa/Cairo"
    "Moscow|Europe/Moscow"
    "Dubai|Asia/Dubai"
    "Mumbai|Asia/Kolkata"
    "Bangkok|Asia/Bangkok"
    "Shanghai|Asia/Shanghai"
    "Tokyo|Asia/Tokyo"
    "Sydney|Australia/Sydney"
    "Auckland|Pacific/Auckland"
)

idx=0
for entry in "${timezones[@]}"; do
    if [[ "$entry" == "LOCAL" ]]; then
        # Detect local timezone city name on macOS
        local_tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' | sed 's|.*/||')
        label="$local_time   Local ($local_tz)"
        sketchybar --set "clock.tz${idx}" label="$label" label.font="$FONT:Bold:14.0"
    else
        city="${entry%%|*}"
        tz="${entry##*|}"
        time_str=$(TZ="$tz" date '+%H:%M')
        label="$time_str   $city"
        sketchybar --set "clock.tz${idx}" label="$label" label.font="$FONT:Medium:14.0"
    fi
    ((idx++))
done

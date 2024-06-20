#!/usr/bin/env bash

INFO="$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}' | xargs networksetup -getairportnetwork | sed "s/Current Wi-Fi Network: //")"

if [ -z "${INFO}" ]; then
  ICON="󰖪"
else
  ICON=""
fi

sketchybar --set "$NAME" icon=$ICON label="$INFO"

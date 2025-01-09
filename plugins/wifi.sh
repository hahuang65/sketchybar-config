#!/usr/bin/env bash

INFO="$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}' | xargs ipconfig getsummary | awk -F ' SSID : ' ' / SSID : / {print $2}')"

if [ -z "${INFO}" ]; then
  ICON="󰖪"
else
  ICON=""
fi

sketchybar --set "$NAME" icon=$ICON label="$INFO"

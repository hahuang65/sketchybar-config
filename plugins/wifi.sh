#!/usr/bin/env bash

# https://apple.stackexchange.com/a/475678
INFO="$(networksetup -listpreferredwirelessnetworks en0 | sed -n '2 p' | tr -d '\t')"

# https://brettterpstra.com/2024/01/29/checking-for-a-vpn-connection-from-the-command-line/
# 0 (utun4 not found) means off, anything else means on
ZSCALER=$(ifconfig -a | grep -c utun4)
if [ "$ZSCALER" -ne 0 ]; then
  INFO="$INFO (Zscaler)"
fi

if [ -z "${INFO}" ]; then
  ICON="󰖪"
else
  ICON=""
fi

sketchybar --set "$NAME" icon=$ICON label="$INFO"

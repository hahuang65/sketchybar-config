#!/usr/bin/env bash

# If INFO isn't set (e.g. on periodic update or external monitor), query it
if [[ -z "$INFO" ]]; then
  INFO=$(osascript -e 'output volume of (get volume settings)')
fi

case ${INFO} in
0)
  ICON=""
  ICON_PADDING_RIGHT=21
  ;;
[0-9])
  ICON=""
  ICON_PADDING_RIGHT=12
  ;;
*)
  ICON=""
  ICON_PADDING_RIGHT=6
  ;;
esac

sketchybar --set "$NAME" icon=$ICON icon.padding_right=$ICON_PADDING_RIGHT label="$INFO%"

#!/usr/bin/env bash

ICON_PADDING=5
ICON_ACTIVE_PADDING=15

case "$1" in
1)
  ICON=""
  ;;
2)
  ICON=""
  ;;
3)
  ICON=""
  ;;
4)
  ICON=""
  ;;
esac

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" background.drawing=on icon="$ICON" icon.padding_left="$ICON_ACTIVE_PADDING" icon.padding_right="$ICON_ACTIVE_PADDING"
else
  sketchybar --set "$NAME" background.drawing=off icon="$ICON" icon.padding_left="$ICON_PADDING" icon.padding_right="$ICON_PADDING"
fi

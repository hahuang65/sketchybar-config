#!/usr/bin/env bash

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
  sketchybar --set "$NAME" icon="$ICON" icon.color=0xfff5a97f
else
  sketchybar --set "$NAME" icon="$ICON" icon.color=0xffcad3f5
fi

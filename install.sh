#!/bin/sh

CONFIG_DIR="${HOME}/.config/sketchybar"

if [ "$(uname)" = "Darwin" ]; then
  ln -sf "${PWD}/sketchybarrc" "${CONFIG_DIR}/sketchybarrc"
  ln -sf "${PWD}/plugins" "${CONFIG_DIR}"
fi

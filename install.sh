#!/bin/sh

CONFIG_DIR="${HOME}/.config/sketchybar"
LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"
PLIST_NAME="com.hhhuang.volume-listener"

if [ "$(uname)" = "Darwin" ]; then
  ln -sf "${PWD}/sketchybarrc" "${CONFIG_DIR}/sketchybarrc"
  ln -sf "${PWD}/plugins" "${CONFIG_DIR}"
  ln -sf "${PWD}/helpers" "${CONFIG_DIR}"

  # Compile volume_listener Swift daemon
  echo "Compiling volume_listener..."
  swiftc -O -o "${PWD}/helpers/volume_listener" "${PWD}/helpers/volume_listener.swift"

  # Install launchd plist for volume_listener
  mkdir -p "${LAUNCH_AGENTS}"
  # Unload existing if running
  launchctl bootout "gui/$(id -u)/${PLIST_NAME}" 2>/dev/null || true
  ln -sf "${PWD}/helpers/${PLIST_NAME}.plist" "${LAUNCH_AGENTS}/${PLIST_NAME}.plist"
  launchctl bootstrap "gui/$(id -u)" "${LAUNCH_AGENTS}/${PLIST_NAME}.plist"
  echo "volume_listener daemon installed and started."
fi

#!/usr/bin/env bash

# Sketchybar microphone plugin
# Hover: show current device name

ICON_MIC=$(printf '\uf130')        # FontAwesome microphone
ICON_MIC_MUTED=$(printf '\uf131')  # FontAwesome microphone-slash

# Handle hover events for popup
if [[ "$SENDER" == "mouse.entered" ]]; then
    sketchybar --set "$NAME" popup.drawing=on
    exit 0
elif [[ "$SENDER" == "mouse.exited" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
fi

# Get input volume
VOL=$(osascript -e 'input volume of (get volume settings)')

if [[ "$VOL" == "missing value" || "$VOL" -eq 0 ]]; then
    ICON="$ICON_MIC_MUTED"
    ICON_COLOR="0xffed8796"
    LABEL=""
else
    ICON="$ICON_MIC"
    ICON_COLOR="0xff8aadf4"
    LABEL="${VOL}%"
fi

# Device name for popup
DEVICE_NAME=$(SwitchAudioSource -c -t input 2>/dev/null)
if [[ -z "$DEVICE_NAME" ]]; then
    DEVICE_NAME="Unknown"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" label="$LABEL"
sketchybar --set microphone.device label="$DEVICE_NAME"

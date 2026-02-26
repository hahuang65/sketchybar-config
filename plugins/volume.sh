#!/usr/bin/env bash

# Sketchybar volume plugin with Bluetooth detection and tiered icons
# Hover: show current device name
# External monitor volume via BetterDisplay HTTP API (localhost:55777)
# Real-time updates via volume_listener daemon (BetterDisplay OSD notifications)

ICON_VOL_OFF=$(printf '\uf026')       # FontAwesome volume-off
ICON_VOL_DOWN=$(printf '\uf027')      # FontAwesome volume-down
ICON_VOL_UP=$(printf '\uf028')        # FontAwesome volume-up
ICON_VOL_MUTED=$(printf '\U000f075f') # nf-md-volume-mute
ICON_BT=$(printf '\uf294')            # FontAwesome bluetooth

# Handle hover events for popup
if [[ "$SENDER" == "mouse.entered" ]]; then
    sketchybar --set "$NAME" popup.drawing=on
    exit 0
elif [[ "$SENDER" == "mouse.exited" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
fi

# --- Fast path for volume change events ---
# bd_volume_change: from our volume_listener daemon (BetterDisplay OSD notifications)
# volume_change: native macOS event (works for built-in/regular speakers only)
#
# When BetterDisplay intercepts media keys for an external monitor, macOS still
# fires volume_change with INFO=0. Ignore that — only trust bd_volume_change for
# DDC monitors, and volume_change with INFO>0 for regular speakers.
if [[ "$SENDER" == "volume_change" && "$INFO" == "0" ]]; then
    # macOS reports 0 for external monitors — skip fast path, do full update below
    :
elif [[ ("$SENDER" == "bd_volume_change" || "$SENDER" == "volume_change") && -n "$INFO" ]]; then
    VOL=$(printf '%.0f' "$INFO")

    if [[ "$VOL" -le 0 ]]; then
        ICON="$ICON_VOL_MUTED"
        ICON_COLOR="0xffed8796"
        ICON_PADDING_RIGHT=5
        LABEL=""
    elif [[ "$VOL" -le 30 ]]; then
        ICON="$ICON_VOL_OFF"
        ICON_COLOR="0xff8aadf4"
        ICON_PADDING_RIGHT=21
        LABEL="${VOL}%"
    elif [[ "$VOL" -le 60 ]]; then
        ICON="$ICON_VOL_DOWN"
        ICON_COLOR="0xff8aadf4"
        ICON_PADDING_RIGHT=12
        LABEL="${VOL}%"
    else
        ICON="$ICON_VOL_UP"
        ICON_COLOR="0xff8aadf4"
        ICON_PADDING_RIGHT=6
        LABEL="${VOL}%"
    fi

    sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" \
        icon.padding_right="$ICON_PADDING_RIGHT" label="$LABEL"
    exit 0
fi

# --- Full update (periodic / initial) ---

DEVICE_NAME=$(SwitchAudioSource -c -t output 2>/dev/null)
if [[ -z "$DEVICE_NAME" ]]; then
    DEVICE_NAME="Unknown"
fi

# Single osascript call for both volume and mute state
VOL_INFO=$(osascript -e 'set v to get volume settings' \
    -e 'set o to output volume of v' \
    -e 'set m to output muted of v' \
    -e 'return (o as text) & "|" & (m as text)' 2>/dev/null)
VOL="${VOL_INFO%%|*}"
MUTED="${VOL_INFO##*|}"

is_bt=0
is_monitor=0

# Handle "missing value" from devices that don't report volume/mute
# (external monitors via DDC, Bluetooth devices).
# Fall back to BetterDisplay HTTP API for external monitor volume.
if [[ "$VOL" == "missing value" ]]; then
    VOL=""
    # Query BetterDisplay for the focused display's volume
    BD_VOL=$(curl -sf --max-time 1 "http://localhost:55777/get?displayWithFocus&volume&value" 2>/dev/null)
    BD_MUTE=$(curl -sf --max-time 1 "http://localhost:55777/get?displayWithFocus&mute" 2>/dev/null)
    if [[ -n "$BD_VOL" && "$BD_VOL" != *"error"* ]]; then
        VOL=$(awk "BEGIN {printf \"%.0f\", $BD_VOL * 100}")
        is_monitor=1
        if [[ "$BD_MUTE" == "on" ]]; then
            MUTED="true"
        fi
    fi
    # If BetterDisplay had no answer, it's likely Bluetooth
    if [[ $is_monitor -eq 0 ]]; then
        is_bt=1
    fi
fi
if [[ "$MUTED" == "missing value" ]]; then
    MUTED=""
fi

# Pick icon
if [[ "$MUTED" == "true" ]]; then
    ICON="$ICON_VOL_MUTED"
    ICON_COLOR="0xffed8796"
    ICON_PADDING_RIGHT=5
elif [[ -z "$VOL" ]]; then
    ICON="$ICON_VOL_UP"
    ICON_COLOR="0xff8aadf4"
    ICON_PADDING_RIGHT=6
elif [[ "$VOL" -le 30 ]]; then
    ICON="$ICON_VOL_OFF"
    ICON_COLOR="0xff8aadf4"
    ICON_PADDING_RIGHT=21
elif [[ "$VOL" -le 60 ]]; then
    ICON="$ICON_VOL_DOWN"
    ICON_COLOR="0xff8aadf4"
    ICON_PADDING_RIGHT=12
else
    ICON="$ICON_VOL_UP"
    ICON_COLOR="0xff8aadf4"
    ICON_PADDING_RIGHT=6
fi

# Prepend bluetooth icon if applicable
if [[ $is_bt -ge 1 && "$MUTED" != "true" ]]; then
    ICON="$ICON_BT $ICON"
    ICON_COLOR="0xff8aadf4"
    ICON_PADDING_RIGHT=5
fi

# Label
if [[ "$MUTED" == "true" || -z "$VOL" ]]; then
    LABEL=""
else
    LABEL="${VOL}%"
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$ICON_COLOR" \
    icon.padding_right="$ICON_PADDING_RIGHT" label="$LABEL"
sketchybar --set volume.device label="$DEVICE_NAME"

#!/usr/bin/env bash

# Sketchybar wifi plugin with VPN indicator and IP geolocation popup
# Ported from waybar network module, adapted for macOS

ICON_WIFI=$(printf '\uf1eb')       # FontAwesome wifi icon
ICON_VPN=$(printf '\U000f033e')    # nf-md-lock
ICON_DISCONNECTED=$(printf '\U000f05aa') # nf-md-wifi-off

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
CACHE_FILE="$CACHE_DIR/remote_ip"
CURL_TIMEOUT=3

mkdir -p "$CACHE_DIR"

# Handle hover events for popup
if [[ "$SENDER" == "mouse.entered" ]]; then
    sketchybar --set "$NAME" popup.drawing=on
    exit 0
elif [[ "$SENDER" == "mouse.exited" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
fi

get_wifi_info() {
    # macOS: get preferred wireless network name
    # https://apple.stackexchange.com/a/475678
    local ssid
    ssid="$(networksetup -listpreferredwirelessnetworks en0 2>/dev/null | sed -n '2 p' | tr -d '\t')"

    if [[ -z "$ssid" ]]; then
        return 1
    fi

    # Get signal strength (RSSI) on macOS
    local rssi
    rssi=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep -i 'agrCtlRSSI' | awk '{print $2}')

    local pct=0
    if [[ -n "$rssi" ]]; then
        if (( rssi >= -30 )); then
            pct=100
        elif (( rssi <= -100 )); then
            pct=0
        else
            pct=$(( (rssi + 100) * 100 / 70 ))
        fi
    fi

    echo "$ssid|$pct"
}

get_vpn_status() {
    # Check for Zscaler by process
    if pgrep -q "Zscaler" 2>/dev/null; then
        echo "Zscaler"
        return 0
    fi

    # Check for active VPN configurations via scutil (covers IKEv2, L2TP, IPSec, etc.)
    if scutil --nc list 2>/dev/null | grep -q Connected; then
        echo "VPN"
        return 0
    fi

    # Check for WireGuard (its interfaces are typically named utun but
    # we verify via the WireGuard process rather than guessing utun numbers,
    # since macOS uses utun interfaces for many system services)
    if pgrep -q "wireguard-go" 2>/dev/null; then
        echo "WireGuard"
        return 0
    fi

    return 1
}

get_local_ip() {
    ipconfig getifaddr en0 2>/dev/null
}

get_remote_ip_info() {
    # Returns "ip|city|country" from cache or fresh lookup.
    # Cache is keyed on VPN status and refreshed every 5 minutes.
    local vpn_state="$1"
    local now
    now=$(date +%s)

    if [[ -f "$CACHE_FILE" ]]; then
        local cached_state cached_time
        cached_state=$(sed -n '1p' "$CACHE_FILE")
        cached_time=$(sed -n '2p' "$CACHE_FILE")
        local age=$(( now - cached_time ))

        # Use cache if VPN state hasn't changed and cache is < 5 min old
        if [[ "$cached_state" == "$vpn_state" && $age -lt 300 ]]; then
            sed -n '3p' "$CACHE_FILE"
            return
        fi
    fi

    # Fetch fresh data
    local json
    json=$(curl -sf --max-time "$CURL_TIMEOUT" https://ipinfo.io/json 2>/dev/null)

    if [[ -n "$json" ]]; then
        local rip rcity rcountry
        rip=$(echo "$json" | jq -r '.ip // empty')
        rcity=$(echo "$json" | jq -r '.city // empty')
        rcountry=$(echo "$json" | jq -r '.country // empty')
        local result="$rip|$rcity|$rcountry"

        # Write cache
        printf '%s\n%s\n%s\n' "$vpn_state" "$now" "$result" > "$CACHE_FILE"
        echo "$result"
    else
        # Return stale cache if available
        [[ -f "$CACHE_FILE" ]] && sed -n '3p' "$CACHE_FILE"
    fi
}

# --- Main ---

wifi_info=$(get_wifi_info)
vpn_name=$(get_vpn_status)
vpn_active=$?
# get_vpn_status returns 0 on success (VPN found)
if [[ $vpn_active -eq 0 ]]; then
    vpn_active=true
else
    vpn_active=false
fi

# Fetch remote IP info (cached)
remote_info=$(get_remote_ip_info "$vpn_active")
remote_ip="${remote_info%%|*}"
remote_loc="${remote_info#*|}"
remote_city="${remote_loc%%|*}"
remote_country="${remote_loc##*|}"

local_ip=$(get_local_ip)

if [[ -n "$wifi_info" ]]; then
    ssid="${wifi_info%%|*}"
    signal="${wifi_info##*|}"

    if [[ "$vpn_active" == true ]]; then
        icon="$ICON_WIFI"
        label="$ssid  $ICON_VPN"
        icon_color="0xffa6da95"  # green
    else
        icon="$ICON_WIFI"
        label="$ssid"
        icon_color="0xffc6a0f6"  # purple (original)
    fi
elif [[ "$vpn_active" == true ]]; then
    icon="$ICON_VPN"
    label="VPN"
    icon_color="0xffa6da95"  # green
else
    icon="$ICON_DISCONNECTED"
    label="NONE"
    icon_color="0xffed8796"  # red
fi

sketchybar --set "$NAME" icon="$icon" label="$label" icon.color="$icon_color"

# Update popup items (icons set separately for proper sizing)
if [[ -n "$wifi_info" ]]; then
    sketchybar --set wifi.ssid     icon="$ICON_WIFI" label="$ssid (${signal}%)" drawing=on
else
    sketchybar --set wifi.ssid     icon="$ICON_WIFI" label="Disconnected" drawing=on
fi

if [[ -n "$local_ip" ]]; then
    sketchybar --set wifi.localip  icon="󰩠" label="$local_ip" drawing=on
else
    sketchybar --set wifi.localip  drawing=off
fi

if [[ "$vpn_active" == true ]]; then
    sketchybar --set wifi.vpn      icon="$ICON_VPN" label="$vpn_name active" drawing=on
else
    sketchybar --set wifi.vpn      drawing=off
fi

if [[ -n "$remote_ip" ]]; then
    sketchybar --set wifi.remote   icon="󰖟" label="$remote_ip ($remote_city, $remote_country)" drawing=on
else
    sketchybar --set wifi.remote   drawing=off
fi

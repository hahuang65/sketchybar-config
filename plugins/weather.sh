#!/usr/bin/env bash

# Sketchybar weather plugin using Open-Meteo (free, no API key, reliable)
# Location detected via ipinfo.io, cached separately
# Ported from waybar weather module

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
CACHE_FILE="$CACHE_DIR/weather.json"
LOCATION_CACHE="$CACHE_DIR/weather_location"
CACHE_MAX_AGE=600  # 10 minutes
LOCATION_MAX_AGE=3600  # 1 hour
CURL_TIMEOUT=5

mkdir -p "$CACHE_DIR"

# Handle hover events for popup
if [[ "$SENDER" == "mouse.entered" ]]; then
    sketchybar --set "$NAME" popup.drawing=on
    exit 0
elif [[ "$SENDER" == "mouse.exited" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
fi

# WMO weather code to icon (same mapping as waybar)
weather_icon() {
    case "$1" in
        0)           printf '\ue30d' ;;  # Clear sky
        1|2)         printf '\ue302' ;;  # Partly cloudy
        3)           printf '\ue312' ;;  # Overcast
        45|48)       printf '\ue313' ;;  # Fog
        51|53|55)    printf '\ue318' ;;  # Drizzle
        56|57)       printf '\ue318' ;;  # Freezing drizzle
        61|63|65)    printf '\ue318' ;;  # Rain
        66|67)       printf '\ue318' ;;  # Freezing rain
        71|73|75|77) printf '\ue31a' ;;  # Snow
        80|81|82)    printf '\ue318' ;;  # Rain showers
        85|86)       printf '\ue31a' ;;  # Snow showers
        95|96|99)    printf '\ue31d' ;;  # Thunderstorm
        *)           printf '\ue312' ;;  # Default cloudy
    esac
}

# WMO weather code to description
weather_desc() {
    case "$1" in
        0)  echo "Clear sky" ;;
        1)  echo "Mainly clear" ;;
        2)  echo "Partly cloudy" ;;
        3)  echo "Overcast" ;;
        45) echo "Fog" ;;
        48) echo "Depositing rime fog" ;;
        51) echo "Light drizzle" ;;
        53) echo "Moderate drizzle" ;;
        55) echo "Dense drizzle" ;;
        56) echo "Light freezing drizzle" ;;
        57) echo "Dense freezing drizzle" ;;
        61) echo "Slight rain" ;;
        63) echo "Moderate rain" ;;
        65) echo "Heavy rain" ;;
        66) echo "Light freezing rain" ;;
        67) echo "Heavy freezing rain" ;;
        71) echo "Slight snow" ;;
        73) echo "Moderate snow" ;;
        75) echo "Heavy snow" ;;
        77) echo "Snow grains" ;;
        80) echo "Slight rain showers" ;;
        81) echo "Moderate rain showers" ;;
        82) echo "Violent rain showers" ;;
        85) echo "Slight snow showers" ;;
        86) echo "Heavy snow showers" ;;
        95) echo "Thunderstorm" ;;
        96) echo "Thunderstorm with slight hail" ;;
        99) echo "Thunderstorm with heavy hail" ;;
        *)  echo "Unknown" ;;
    esac
}

# Wind direction from degrees
wind_direction() {
    local deg=$1
    local dirs=("N" "NNE" "NE" "ENE" "E" "ESE" "SE" "SSE" "S" "SSW" "SW" "WSW" "W" "WNW" "NW" "NNW")
    local idx=$(( (deg + 11) % 360 / 22 ))
    echo "${dirs[$idx]}"
}

# Get location (cached separately since it changes less often)
get_location() {
    if [[ -f "$LOCATION_CACHE" ]]; then
        age=$(( $(date +%s) - $(stat -f %m "$LOCATION_CACHE") ))
        if (( age < LOCATION_MAX_AGE )); then
            cat "$LOCATION_CACHE"
            return
        fi
    fi

    local loc_data
    loc_data=$(curl -sf --max-time "$CURL_TIMEOUT" "https://ipinfo.io/json" 2>/dev/null)
    if [[ -n "$loc_data" ]]; then
        local coords city region
        coords=$(echo "$loc_data" | jq -r '.loc')
        city=$(echo "$loc_data" | jq -r '.city')
        region=$(echo "$loc_data" | jq -r '.region')
        local lat lon
        lat="${coords%%,*}"
        lon="${coords##*,}"
        printf '%s|%s|%s, %s' "$lat" "$lon" "$city" "$region" > "$LOCATION_CACHE"
        cat "$LOCATION_CACHE"
    fi
}

update_weather() {
    # Use cache if fresh enough
    if [[ -f "$CACHE_FILE" ]]; then
        age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
        has_details=$(jq -r '.desc // empty' "$CACHE_FILE" 2>/dev/null)
        if (( age < CACHE_MAX_AGE )) && [[ -n "$has_details" ]]; then
            icon=$(jq -r '.icon' "$CACHE_FILE")
            label=$(jq -r '.label' "$CACHE_FILE")
            sketchybar --set "$NAME" icon="$icon" label="$label"
            update_popup
            return
        fi
    fi

    location_info=$(get_location)
    if [[ -z "$location_info" ]]; then
        sketchybar --set "$NAME" icon="" label="N/A"
        return
    fi

    lat="${location_info%%|*}"
    rest="${location_info#*|}"
    lon="${rest%%|*}"
    location_name="${rest#*|}"

    # Fetch weather from Open-Meteo
    weather=$(curl -sf --max-time "$CURL_TIMEOUT" \
        "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,weather_code&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto&forecast_days=2" \
        2>/dev/null)

    if [[ -z "$weather" ]]; then
        sketchybar --set "$NAME" icon="" label="N/A"
        return
    fi

    # Parse current conditions
    temp=$(echo "$weather" | jq -r '.current.temperature_2m | round')
    feels_like=$(echo "$weather" | jq -r '.current.apparent_temperature | round')
    humidity=$(echo "$weather" | jq -r '.current.relative_humidity_2m')
    wind_speed=$(echo "$weather" | jq -r '.current.wind_speed_10m | round')
    wind_deg=$(echo "$weather" | jq -r '.current.wind_direction_10m')
    code=$(echo "$weather" | jq -r '.current.weather_code')

    icon=$(weather_icon "$code")
    desc=$(weather_desc "$code")
    wind_dir=$(wind_direction "$wind_deg")
    label="${temp}°F  ${location_name}"

    # Build 12-hour forecast (next 4 three-hour slots)
    current_hour=$(date +%-H)
    current_date=$(date +%Y-%m-%d)

    fc_icons=()
    fc_labels=()
    slots_found=0
    slots_needed=4

    hourly_times=$(echo "$weather" | jq -r '.hourly.time[]')
    hourly_temps=$(echo "$weather" | jq -r '.hourly.temperature_2m[]')
    hourly_codes=$(echo "$weather" | jq -r '.hourly.weather_code[]')

    mapfile -t times <<< "$hourly_times"
    mapfile -t temps <<< "$hourly_temps"
    mapfile -t codes <<< "$hourly_codes"

    for i in "${!times[@]}"; do
        if (( slots_found >= slots_needed )); then
            break
        fi

        fc_datetime="${times[$i]}"
        fc_date="${fc_datetime%%T*}"
        fc_time="${fc_datetime##*T}"
        fc_hour="${fc_time%%:*}"

        # Skip past hours and only pick every 3rd hour
        if [[ "$fc_date" == "$current_date" && "10#$fc_hour" -le "$current_hour" ]]; then
            continue
        fi
        if (( 10#$fc_hour % 3 != 0 )); then
            continue
        fi

        fc_temp=$(printf '%.0f' "${temps[$i]}")
        fc_code="${codes[$i]}"
        fc_icon=$(weather_icon "$fc_code")
        fc_desc=$(weather_desc "$fc_code")

        if [[ "$fc_date" == "$current_date" ]]; then
            fc_label=$(printf "%02d:00  %s°F  %s" "$((10#$fc_hour))" "$fc_temp" "$fc_desc")
        else
            fc_label=$(printf "Tmrw %02d:00  %s°F  %s" "$((10#$fc_hour))" "$fc_temp" "$fc_desc")
        fi

        fc_icons+=("$fc_icon")
        fc_labels+=("$fc_label")
        ((slots_found++))
    done

    # Cache everything
    jq -nc \
        --arg icon "$icon" \
        --arg label "$label" \
        --arg desc "$desc" \
        --arg feels_like "$feels_like" \
        --arg humidity "$humidity" \
        --arg wind_speed "$wind_speed" \
        --arg wind_dir "$wind_dir" \
        --arg fc0 "${fc_labels[0]:-}" --arg fc0_icon "${fc_icons[0]:-}" \
        --arg fc1 "${fc_labels[1]:-}" --arg fc1_icon "${fc_icons[1]:-}" \
        --arg fc2 "${fc_labels[2]:-}" --arg fc2_icon "${fc_icons[2]:-}" \
        --arg fc3 "${fc_labels[3]:-}" --arg fc3_icon "${fc_icons[3]:-}" \
        '{icon: $icon, label: $label, desc: $desc, feels_like: $feels_like,
          humidity: $humidity, wind_speed: $wind_speed, wind_dir: $wind_dir,
          fc0: $fc0, fc0_icon: $fc0_icon, fc1: $fc1, fc1_icon: $fc1_icon,
          fc2: $fc2, fc2_icon: $fc2_icon, fc3: $fc3, fc3_icon: $fc3_icon}' > "$CACHE_FILE"

    sketchybar --set "$NAME" icon="$icon" label="$label"
    update_popup
}

update_popup() {
    [[ ! -f "$CACHE_FILE" ]] && return

    icon=$(jq -r '.icon // empty' "$CACHE_FILE")
    desc=$(jq -r '.desc // empty' "$CACHE_FILE")
    feels_like=$(jq -r '.feels_like // empty' "$CACHE_FILE")
    humidity=$(jq -r '.humidity // empty' "$CACHE_FILE")
    wind_speed=$(jq -r '.wind_speed // empty' "$CACHE_FILE")
    wind_dir=$(jq -r '.wind_dir // empty' "$CACHE_FILE")

    [[ -z "$desc" ]] && return

    sketchybar \
        --set weather.desc     icon="$icon" label="$desc" \
        --set weather.feels    icon= label="Feels like ${feels_like}°F" \
        --set weather.humidity icon= label="Humidity ${humidity}%" \
        --set weather.wind     icon= label="Wind ${wind_speed} mph ${wind_dir}"

    for i in 0 1 2 3; do
        fc=$(jq -r ".fc${i} // empty" "$CACHE_FILE")
        fc_icon=$(jq -r ".fc${i}_icon // empty" "$CACHE_FILE")
        if [[ -n "$fc" ]]; then
            sketchybar --set "weather.fc${i}" icon="$fc_icon" label="$fc" drawing=on
        else
            sketchybar --set "weather.fc${i}" drawing=off
        fi
    done
}

update_weather

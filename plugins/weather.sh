#!/usr/bin/env bash

# Sketchybar weather plugin using wttr.in
# Auto-detects location via IP geolocation (ported from waybar)

CACHE_FILE="/tmp/sketchybar-weather.json"
CACHE_MAX_AGE=600 # 10 minutes

# Handle hover events for popup
if [[ "$SENDER" == "mouse.entered" ]]; then
    sketchybar --set "$NAME" popup.drawing=on
    exit 0
elif [[ "$SENDER" == "mouse.exited.global" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
fi

# Map weather code to icon
weather_icon() {
    case "$1" in
        113) printf '\ue30d' ;;                    # Clear/Sunny
        116) printf '\ue302' ;;                    # Partly cloudy
        119|122) printf '\ue312' ;;                # Cloudy/Overcast
        143|248|260) printf '\ue313' ;;            # Fog/Mist
        176|263|266|293|296) printf '\ue318' ;;    # Light rain/drizzle
        299|302|305|308|356|359) printf '\ue318' ;; # Heavy rain
        179|227|320|323|326|329|332|335|338|368|371|395) printf '\ue31a' ;; # Snow
        200|386|389|392) printf '\ue31d' ;;        # Thunderstorm
        *) printf '\ue312' ;;                      # Default cloudy
    esac
}

update_weather() {
    # Use cache if fresh enough and has all fields
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

    # Detect location via ipinfo.io
    loc_data=$(curl -sf "https://ipinfo.io/json" 2>/dev/null)
    if [[ -n "$loc_data" ]]; then
        loc_coords=$(echo "$loc_data" | jq -r '.loc')  # "lat,lon"
        loc_city=$(echo "$loc_data" | jq -r '.city')
        loc_region=$(echo "$loc_data" | jq -r '.region')
        location="${loc_city}, ${loc_region}"
        weather=$(curl -sf "wttr.in/${loc_coords}?format=j1" 2>/dev/null)
    else
        weather=$(curl -sf "wttr.in/?format=j1" 2>/dev/null)
        location=""
    fi

    if [[ -z "$weather" ]]; then
        sketchybar --set "$NAME" icon="" label="N/A"
        return
    fi

    # Fall back to wttr.in location if ipinfo.io didn't provide one
    if [[ -z "$location" ]]; then
        location=$(echo "$weather" | jq -r '.nearest_area[0] | "\(.areaName[0].value), \(.region[0].value)"')
    fi

    temp=$(echo "$weather" | jq -r '.current_condition[0].temp_F')
    feels_like=$(echo "$weather" | jq -r '.current_condition[0].FeelsLikeF')
    humidity=$(echo "$weather" | jq -r '.current_condition[0].humidity')
    desc=$(echo "$weather" | jq -r '.current_condition[0].weatherDesc[0].value')
    wind_speed=$(echo "$weather" | jq -r '.current_condition[0].windspeedMiles')
    wind_dir=$(echo "$weather" | jq -r '.current_condition[0].winddir16Point')
    code=$(echo "$weather" | jq -r '.current_condition[0].weatherCode')
    icon=$(weather_icon "$code")
    label="${temp}°F  ${location}"

    # Build 12-hour forecast (next 4 three-hour slots)
    current_hour=$(date +%-H)
    fc_icons=()
    fc_labels=()
    slots_needed=4
    slots_found=0

    for day_idx in 0 1; do
        while IFS= read -r entry; do
            time_val=$(echo "$entry" | jq -r '.time')
            hour=$((10#$time_val / 100))

            if [[ $day_idx -eq 0 && $hour -le $current_hour ]]; then
                continue
            fi
            if (( slots_found >= slots_needed )); then
                break
            fi

            fc_temp=$(echo "$entry" | jq -r '.tempF')
            fc_code=$(echo "$entry" | jq -r '.weatherCode')
            fc_desc=$(echo "$entry" | jq -r '.weatherDesc[0].value' | xargs)
            fc_icon=$(weather_icon "$fc_code")

            if [[ $day_idx -eq 0 ]]; then
                fc_time=$(printf "%02d:00" "$hour")
            else
                fc_time=$(printf "Tmrw %02d:00" "$hour")
            fi

            fc_icons+=("$fc_icon")
            fc_labels+=("${fc_time}  ${fc_temp}°F  ${fc_desc}")
            ((slots_found++))
        done < <(echo "$weather" | jq -c ".weather[$day_idx].hourly[]")

        if (( slots_found >= slots_needed )); then
            break
        fi
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

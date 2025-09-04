#!/usr/bin/env bash

WIFI_NAME=$(networksetup -listpreferredwirelessnetworks en0 | sed -n '2 p' | tr -d '\t')

if [ "$WIFI_NAME" = "Kiwi" ]; then
  WEATHER_JSON=$(curl -s "https://wttr.in/77386?format=j1")
else
  WEATHER_JSON=$(curl -s "https://wttr.in/?format=j1")
fi

# Fallback if empty
if [ -z "$WEATHER_JSON" ]; then
  sketchybar --set "$NAME" label="UNKNOWN LOCATION"
  return
fi

CITY="$(echo "$WEATHER_JSON" | jq '.nearest_area[0].areaName[].value' | tr -d '"')"
REGION="$(echo "$WEATHER_JSON" | jq '.nearest_area[0].region[].value' | tr -d '"')"
TEMPERATURE=$(echo "$WEATHER_JSON" | jq '.current_condition[0].temp_F' | tr -d '"')
WEATHER_DESCRIPTION=$(echo "$WEATHER_JSON" | jq '.current_condition[0].weatherDesc[0].value' | tr -d '"' | sed 's/\(.\{25\}\).*/\1.../')

sketchybar --set "$NAME" label="$CITY, $REGION  ${TEMPERATURE}°F $WEATHER_DESCRIPTION"

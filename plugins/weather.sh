#!/usr/bin/env bash

IP=$(curl -s https://ipinfo.io/ip)
LOCATION=$(curl -s https://ipinfo.io/"$IP"/json | jq '.loc' | tr -d '"')
WEATHER_JSON=$(curl -s "https://wttr.in/$LOCATION?format=j1")

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

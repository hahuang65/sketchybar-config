#!/usr/bin/env bash

IP=$(curl -s https://ipinfo.io/ip)
LOCATION_JSON=$(curl -s https://ipinfo.io/"$IP"/json)

LOCATION="$(echo "$LOCATION_JSON" | jq '.city' | tr -d '"')"
REGION="$(echo "$LOCATION_JSON" | jq '.region' | tr -d '"')"
_COUNTRY="$(echo "$LOCATION_JSON" | jq '.country' | tr -d '"')"

# Line below replaces spaces with +
LOCATION_ESCAPED="${LOCATION// /+}+${REGION// /+}"
WEATHER_JSON=$(curl -s "https://wttr.in/$LOCATION_ESCAPED?format=j1")

# Fallback if empty
if [ -z "$WEATHER_JSON" ]; then

  sketchybar --set "$NAME" label="$LOCATION"
  sketchybar --set "$NAME".moon icon=

  return
fi

TEMPERATURE=$(echo "$WEATHER_JSON" | jq '.current_condition[0].temp_F' | tr -d '"')
WEATHER_DESCRIPTION=$(echo "$WEATHER_JSON" | jq '.current_condition[0].weatherDesc[0].value' | tr -d '"' | sed 's/\(.\{25\}\).*/\1.../')

sketchybar --set "$NAME" label="$LOCATION, $REGION  ${TEMPERATURE}°F $WEATHER_DESCRIPTION"

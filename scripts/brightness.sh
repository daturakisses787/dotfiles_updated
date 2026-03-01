#!/usr/bin/env bash
# brightness.sh – Brightness control with dunst notification and progress bar
# Usage: brightness.sh [up|down|set <value>]
# Requires: brightnessctl, dunst

set -euo pipefail

readonly STEP="${BRIGHTNESS_STEP:-5}"

get_brightness_percent() {
    # brightnessctl -m outputs: device,max,current,percent%,flags
    brightnessctl -m | cut -d',' -f4 | tr -d '%'
}

send_notification() {
    local brightness
    brightness="$(get_brightness_percent)"

    dunstify \
        --appname "brightness" \
        --urgency low \
        --icon "display-brightness" \
        --hints "string:x-dunst-stack-tag:brightness" \
        --hints "int:value:${brightness}" \
        "Brightness" "${brightness}%"
}

case "${1:-}" in
    up)
        brightnessctl set "+${STEP}%" --quiet
        send_notification
        ;;
    down)
        # Prevent going below 5%
        brightnessctl set "${STEP}%-" --quiet --min-value=5
        send_notification
        ;;
    set)
        if [[ -z "${2:-}" ]]; then
            printf 'Usage: %s set <0-100>\n' "$(basename "$0")" >&2
            exit 1
        fi
        brightnessctl set "${2}%" --quiet
        send_notification
        ;;
    *)
        printf 'Usage: %s [up|down|set <value>]\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac

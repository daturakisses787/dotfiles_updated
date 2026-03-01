#!/usr/bin/env bash
# volume.sh – Volume control with dunst notification and progress bar
# Usage: volume.sh [up|down|mute]
# Requires: pamixer, dunst, libnotify

set -euo pipefail

readonly STEP="${VOLUME_STEP:-5}"
readonly MAX_VOL=150  # Allow up to 150% via pamixer --allow-boost

get_volume() {
    pamixer --get-volume
}

is_muted() {
    pamixer --get-mute
}

get_icon() {
    local vol="$1"
    local muted="$2"

    if [[ "$muted" == "true" ]]; then
        printf 'audio-volume-muted'
    elif (( vol < 33 )); then
        printf 'audio-volume-low'
    elif (( vol < 66 )); then
        printf 'audio-volume-medium'
    else
        printf 'audio-volume-high'
    fi
}

send_notification() {
    local vol
    local muted
    vol="$(get_volume)"
    muted="$(is_muted)"

    local icon
    icon="$(get_icon "$vol" "$muted")"

    local label
    if [[ "$muted" == "true" ]]; then
        label="Muted"
    else
        label="${vol}%"
    fi

    # dunstify with stack tag and progress bar value
    dunstify \
        --appname "volume" \
        --urgency low \
        --icon "$icon" \
        --hints "string:x-dunst-stack-tag:volume" \
        --hints "int:value:${vol}" \
        "Volume" "$label"
}

case "${1:-}" in
    up)
        pamixer --unmute
        pamixer --increase "$STEP" --allow-boost --set-limit "$MAX_VOL"
        send_notification
        ;;
    down)
        pamixer --unmute
        pamixer --decrease "$STEP"
        send_notification
        ;;
    mute)
        pamixer --toggle-mute
        send_notification
        ;;
    *)
        printf 'Usage: %s [up|down|mute]\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac

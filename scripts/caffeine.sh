#!/usr/bin/env bash
# caffeine.sh – Toggle hypridle to keep the system awake
# Usage: caffeine.sh [toggle|on|off|status]
# Requires: hypridle, dunst, libnotify

set -euo pipefail

readonly STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/caffeine-mode"
readonly WAYBAR_SIGNAL=8

get_state() {
    if [[ -f "$STATE_FILE" ]] && [[ "$(< "$STATE_FILE")" == "on" ]]; then
        printf 'on'
    else
        printf 'off'
    fi
}

caffeine_on() {
    if pgrep -x hypridle > /dev/null 2>&1; then
        pkill -x hypridle
    fi
    printf 'on' > "$STATE_FILE"
    pkill -RTMIN+${WAYBAR_SIGNAL} waybar 2>/dev/null || true
    dunstify \
        -a "caffeine" \
        -u low \
        -i "caffeine-cup-full" \
        -h "string:x-dunst-stack-tag:caffeine" \
        "Caffeine Mode" "Active – system stays awake"
}

caffeine_off() {
    printf 'off' > "$STATE_FILE"
    if ! pgrep -x hypridle > /dev/null 2>&1; then
        hypridle &
        disown
    fi
    pkill -RTMIN+${WAYBAR_SIGNAL} waybar 2>/dev/null || true
    dunstify \
        -a "caffeine" \
        -u low \
        -i "caffeine-cup-empty" \
        -h "string:x-dunst-stack-tag:caffeine" \
        "Caffeine Mode" "Off – idle timers restored"
}

waybar_status() {
    local state
    state="$(get_state)"
    if [[ "$state" == "on" ]]; then
        printf '{"text": "󰛊", "tooltip": "Caffeine: active – idle timers disabled", "class": "active"}\n'
    else
        printf '{"text": "󰛊", "tooltip": "Caffeine: off – idle timers active", "class": "inactive"}\n'
    fi
}

case "${1:-toggle}" in
    toggle)
        if [[ "$(get_state)" == "on" ]]; then
            caffeine_off
        else
            caffeine_on
        fi
        ;;
    on)
        caffeine_on
        ;;
    off)
        caffeine_off
        ;;
    status)
        waybar_status
        ;;
    *)
        printf 'Usage: %s [toggle|on|off|status]\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac

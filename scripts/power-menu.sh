#!/usr/bin/env bash
# power-menu.sh – Power menu using wofi dmenu
# Options: Lock, Logout, Suspend, Hibernate, Reboot, Shutdown

set -euo pipefail

# Menu entries with icons (Nerd Font)
readonly OPT_LOCK="󰌾  Lock"
readonly OPT_LOGOUT="󰍃  Logout"
readonly OPT_SUSPEND="󰤄  Suspend"
readonly OPT_HIBERNATE="󰤁  Hibernate"
readonly OPT_REBOOT="󰜉  Reboot"
readonly OPT_SHUTDOWN="󰐥  Shutdown"

# Show wofi dmenu and capture selection
chosen="$(printf '%s\n%s\n%s\n%s\n%s\n%s' \
    "$OPT_LOCK" \
    "$OPT_LOGOUT" \
    "$OPT_SUSPEND" \
    "$OPT_HIBERNATE" \
    "$OPT_REBOOT" \
    "$OPT_SHUTDOWN" \
    | wofi \
        --dmenu \
        --prompt "  Power" \
        --width 220 \
        --height 320 \
        --cache-file /dev/null \
        --style "${XDG_CONFIG_HOME:-$HOME/.config}/wofi/style.css" \
        2>/dev/null)"

# Execute chosen action
case "$chosen" in
    "$OPT_LOCK")      loginctl lock-session ;;
    "$OPT_LOGOUT")    hyprctl dispatch exit ;;
    "$OPT_SUSPEND")   systemctl suspend ;;
    "$OPT_HIBERNATE") systemctl hibernate ;;
    "$OPT_REBOOT")    systemctl reboot ;;
    "$OPT_SHUTDOWN")  systemctl poweroff ;;
    "")               ;; # User cancelled
    *)
        printf 'Unknown option: %s\n' "$chosen" >&2
        exit 1
        ;;
esac

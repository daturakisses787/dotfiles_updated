#!/usr/bin/env bash
set -euo pipefail

# Break reminder overlay – shows a fullscreen message, dismissed with SPACE

SCRIPT_PATH="$(readlink -f "$0")"
CLASS="break-reminder"
MESSAGE="Mache eine kurze Pause und stehe einmal auf!"
HINT="[ SPACE ]"
INTERVAL_MIN="${BREAK_INTERVAL:-60}"

# Daemon mode: runs in background and triggers reminder every INTERVAL_MIN minutes
if [[ "${1:-}" == "--daemon" ]]; then
    # Wait one full interval before showing the first reminder
    while true; do
        sleep $(( INTERVAL_MIN * 60 ))
        "$SCRIPT_PATH" &
        wait $! || true
    done
fi

# Inner mode: runs inside the terminal overlay
if [[ "${1:-}" == "--inner" ]]; then
    # Hide cursor
    tput civis
    trap 'tput cnorm' EXIT

    draw_screen() {
        clear
        local cols lines msg_row hint_row msg_col hint_col
        cols=$(tput cols)
        lines=$(tput lines)

        msg_row=$(( (lines / 2) - 1 ))
        hint_row=$(( msg_row + 2 ))
        msg_col=$(( (cols - ${#MESSAGE}) / 2 ))
        hint_col=$(( (cols - ${#HINT}) / 2 ))
        (( msg_col < 0 )) && msg_col=0
        (( hint_col < 0 )) && hint_col=0

        tput cup "$msg_row" "$msg_col"
        printf '\033[1;37m%s\033[0m' "$MESSAGE"
        tput cup "$hint_row" "$hint_col"
        printf '\033[0;90m%s\033[0m' "$HINT"
        tput cup "$lines" 0
    }

    # Redraw on terminal resize (fullscreen toggle)
    trap draw_screen WINCH

    draw_screen

    # Wait for SPACE (read can return non-zero on resize signal)
    while true; do
        IFS= read -rsn1 key || continue
        if [[ "$key" == " " ]]; then
            break
        fi
    done

    exit 0
fi

# Hide waybar
pkill -SIGUSR1 waybar || true

# Read monitor info: "name width height x y" per line
mapfile -t MONITORS < <(hyprctl monitors -j | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    print(m["name"], m["width"], m["height"], m["x"], m["y"])
')

KITTY_PIDS=()

# Spawn one kitty per monitor
for mon_info in "${MONITORS[@]}"; do
    read -r _name mon_w mon_h mon_x mon_y <<< "$mon_info"

    kitty --class "$CLASS" -o background_opacity=0.85 -o background="#1a1a2e" \
        -o font_size=24 -o cursor_shape=block -o shell_integration=disabled \
        -e "$SCRIPT_PATH" --inner &
    KITTY_PIDS+=($!)

    # Wait for this window to appear, then position it on the correct monitor
    for _ in $(seq 1 20); do
        sleep 0.1
        # Count how many break-reminder windows exist vs how many we expect
        win_count=$(hyprctl clients -j | grep -c "$CLASS" || true)
        if [[ "$win_count" -ge "${#KITTY_PIDS[@]}" ]]; then
            # Move the most recently spawned window (has focus) to the correct position
            hyprctl dispatch movewindowpixel "exact ${mon_x} ${mon_y},class:${CLASS}"
            hyprctl dispatch resizewindowpixel "exact ${mon_w} ${mon_h},class:${CLASS}"
            break
        fi
    done
done

# Wait for ANY kitty to exit (user pressed SPACE on one of them)
wait -n "${KITTY_PIDS[@]}" 2>/dev/null || true

# Kill all remaining break-reminder windows
for pid in "${KITTY_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
done
wait 2>/dev/null || true

# Show waybar again
pkill -SIGUSR1 waybar || true

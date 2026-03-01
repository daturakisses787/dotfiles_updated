#!/usr/bin/env bash
# screenshot.sh – Screenshot utility using grim and slurp
# Usage: screenshot.sh [area|screen|window]
# Saves to ~/Pictures/Screenshots and copies to clipboard

set -euo pipefail

readonly SCREENSHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
readonly TIMESTAMP
readonly FILENAME="screenshot_${TIMESTAMP}.png"
readonly OUTFILE="${SCREENSHOT_DIR}/${FILENAME}"

# Ensure output directory exists
mkdir -p "$SCREENSHOT_DIR"

# Send a dunst notification with optional image preview
notify_screenshot() {
    local message="$1"
    local file="${2:-}"

    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        notify-send \
            -i "$file" \
            -h "string:x-dunst-stack-tag:screenshot" \
            -u low \
            "Screenshot" "$message"
    else
        notify-send \
            -h "string:x-dunst-stack-tag:screenshot" \
            -u low \
            "Screenshot" "$message"
    fi
}

# Capture a user-selected area
take_area() {
    local selection
    # slurp opens a crosshair selector; exits with error if user cancels
    if selection="$(slurp -d 2>/dev/null)"; then
        grim -g "$selection" "$OUTFILE"
        wl-copy < "$OUTFILE"
        notify_screenshot "Area saved: ${FILENAME}" "$OUTFILE"
    else
        notify_screenshot "Cancelled."
    fi
}

# Capture the full screen (all monitors)
take_screen() {
    grim "$OUTFILE"
    wl-copy < "$OUTFILE"
    notify_screenshot "Screen saved: ${FILENAME}" "$OUTFILE"
}

# Capture the active window (using hyprctl to get geometry)
take_window() {
    local geometry
    geometry="$(hyprctl activewindow -j \
        | grep -oP '"at":\[.*?\]|"size":\[.*?\]' \
        | awk -F'[][]' '
            /at/   { split($2,a,","); x=a[1]; y=a[2] }
            /size/ { split($2,a,","); w=a[1]; h=a[2] }
            END    { printf "%s,%s %sx%s", x, y, w, h }
        ')"

    if [[ -n "$geometry" ]]; then
        grim -g "$geometry" "$OUTFILE"
        wl-copy < "$OUTFILE"
        notify_screenshot "Window saved: ${FILENAME}" "$OUTFILE"
    else
        notify_screenshot "Could not detect active window." ""
    fi
}

case "${1:-screen}" in
    area)   take_area ;;
    screen) take_screen ;;
    window) take_window ;;
    *)
        printf 'Usage: %s [area|screen|window]\n' "$(basename "$0")" >&2
        exit 1
        ;;
esac

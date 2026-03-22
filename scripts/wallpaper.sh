#!/usr/bin/env bash
# wallpaper.sh – Random wallpaper rotation using swww
# Rotates a random wallpaper from WALLPAPER_DIR every INTERVAL seconds
# Also maintains a symlink at ~/.cache/current-wallpaper for hyprlock

set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wallpapers}"
WALLPAPER_DIR="$(readlink -f "$WALLPAPER_DIR")"
readonly WALLPAPER_DIR
readonly INTERVAL="${WALLPAPER_INTERVAL:-3600}"  # 60 minutes
readonly CURRENT_LINK="${XDG_CACHE_HOME:-$HOME/.cache}/current-wallpaper"
readonly TRANSITION="${WALLPAPER_TRANSITION:-wipe}"
readonly TRANSITION_DURATION="${WALLPAPER_TRANSITION_DURATION:-2}"
readonly TRANSITION_FPS="${WALLPAPER_TRANSITION_FPS:-60}"
readonly TRANSITION_ANGLE="${WALLPAPER_TRANSITION_ANGLE:-30}"
readonly PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-daemon.pid"

# Ensure cache directory exists
mkdir -p "$(dirname "$CURRENT_LINK")"

# Wait for swww daemon to be ready (up to 5 seconds)
wait_for_swww() {
    local retries=10
    while (( retries > 0 )); do
        if swww query &>/dev/null; then
            return 0
        fi
        sleep 0.5
        (( retries-- ))
    done
    printf 'swww-daemon not responding after 5 seconds\n' >&2
    return 1
}

# Select and apply a random wallpaper from WALLPAPER_DIR
set_random_wallpaper() {
    local wallpaper

    # Collect all supported image files (null-delimited for safety with spaces)
    mapfile -d '' wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 2 \
        -type f \( \
            -iname "*.jpg"  -o \
            -iname "*.jpeg" -o \
            -iname "*.png"  -o \
            -iname "*.webp" \
        \) \
        -print0 2>/dev/null)

    if [[ "${#wallpapers[@]}" -eq 0 ]]; then
        printf 'No wallpapers found in %s\n' "$WALLPAPER_DIR" >&2
        return 1
    fi

    # Pick a random index using RANDOM (0..32767)
    local idx=$(( RANDOM % ${#wallpapers[@]} ))
    wallpaper="${wallpapers[$idx]}"

    # Apply wallpaper with smooth transition
    swww img "$wallpaper" \
        --transition-type "$TRANSITION" \
        --transition-angle "$TRANSITION_ANGLE" \
        --transition-duration "$TRANSITION_DURATION" \
        --transition-fps "$TRANSITION_FPS"

    # Update current wallpaper symlink (used by hyprlock)
    ln -sfn "$wallpaper" "$CURRENT_LINK"

    # Trigger automatic theme switch based on wallpaper color group
    local scripts_dir
    scripts_dir="$(dirname "$(readlink -f "$0")")"
    if [[ -x "${scripts_dir}/theme-toggle.sh" ]]; then
        "${scripts_dir}/theme-toggle.sh" --auto "$wallpaper" &
    fi

    printf 'Wallpaper set: %s\n' "$(basename "$wallpaper")"
}

main() {
    # Ensure wallpaper directory exists
    if [[ ! -d "$WALLPAPER_DIR" ]]; then
        mkdir -p "$WALLPAPER_DIR"
        printf 'Created wallpaper directory: %s\n' "$WALLPAPER_DIR"
        printf 'Add wallpapers (jpg/png/webp) and restart this script.\n'
        exit 0
    fi

    # Wait for swww daemon
    if ! wait_for_swww; then
        printf 'Starting swww-daemon...\n'
        swww-daemon &
        sleep 1
    fi

    # Single switch mode (for keybind usage)
    if [[ "${1:-}" == "--once" ]]; then
        set_random_wallpaper
        exit $?
    fi

    # Write PID file so wallpaper-picker can detect and stop the daemon
    echo $$ > "$PID_FILE"
    trap 'rm -f "$PID_FILE"' EXIT INT TERM

    # Rotation loop
    while true; do
        if ! set_random_wallpaper; then
            # No wallpapers found – poll every 10s instead of waiting full interval
            sleep 10
            continue
        fi
        sleep "$INTERVAL"
    done
}

main "$@"

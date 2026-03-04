#!/usr/bin/env bash
# wallpaper-picker.sh – Visual wallpaper picker using rofi grid with image previews
# Opens a rofi window showing all wallpapers as a grid; selection applies the wallpaper

set -euo pipefail

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wallpapers}"
WALLPAPER_DIR="$(readlink -f "$WALLPAPER_DIR")"
readonly WALLPAPER_DIR
readonly CURRENT_LINK="${XDG_CACHE_HOME:-$HOME/.cache}/current-wallpaper"
readonly ROFI_THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallpaper-picker.rasi"

# Transition settings (shared with wallpaper.sh)
readonly TRANSITION="${WALLPAPER_TRANSITION:-wipe}"
readonly TRANSITION_DURATION="${WALLPAPER_TRANSITION_DURATION:-2}"
readonly TRANSITION_FPS="${WALLPAPER_TRANSITION_FPS:-60}"
readonly TRANSITION_ANGLE="${WALLPAPER_TRANSITION_ANGLE:-30}"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    notify-send "Wallpaper Picker" "Wallpaper directory not found: $WALLPAPER_DIR"
    exit 1
fi

# Collect wallpapers
mapfile -d '' wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 2 \
    -type f \( \
        -iname "*.jpg"  -o \
        -iname "*.jpeg" -o \
        -iname "*.png"  -o \
        -iname "*.webp" \
    \) \
    -print0 2>/dev/null | sort -z)

if [[ "${#wallpapers[@]}" -eq 0 ]]; then
    notify-send "Wallpaper Picker" "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# Build rofi input: each line is "filename\0icon\x1f/full/path"
rofi_input=""
for wp in "${wallpapers[@]}"; do
    name="$(basename "$wp")"
    # Remove file extension for cleaner display
    name="${name%.*}"
    rofi_input+="${name}\0icon\x1f${wp}\n"
done

# Show rofi picker and get selection
chosen="$(printf '%b' "$rofi_input" | rofi -dmenu \
    -i \
    -p "" \
    -theme "$ROFI_THEME" \
    -show-icons)" || exit 0

# Find the full path matching the chosen name
selected_path=""
for wp in "${wallpapers[@]}"; do
    name="$(basename "$wp")"
    name="${name%.*}"
    if [[ "$name" == "$chosen" ]]; then
        selected_path="$wp"
        break
    fi
done

if [[ -z "$selected_path" ]]; then
    exit 1
fi

# Apply wallpaper with swww
swww img "$selected_path" \
    --transition-type "$TRANSITION" \
    --transition-angle "$TRANSITION_ANGLE" \
    --transition-duration "$TRANSITION_DURATION" \
    --transition-fps "$TRANSITION_FPS"

# Update current wallpaper symlink (used by hyprlock)
ln -sfn "$selected_path" "$CURRENT_LINK"

# Trigger automatic theme switch
scripts_dir="$(dirname "$(readlink -f "$0")")"
if [[ -x "${scripts_dir}/theme-toggle.sh" ]]; then
    "${scripts_dir}/theme-toggle.sh" --auto "$selected_path" &
fi

notify-send "Wallpaper" "$(basename "$selected_path")"

#!/usr/bin/env bash
# generate-themes.sh – Analyze wallpapers and generate dynamic color-grouped themes
# Usage: generate-themes.sh [--recluster|--remap|--regenerate|--add <file>]
# Requires: ImageMagick (magick), python3

set -euo pipefail

readonly DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
readonly WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/wallpapers}"
readonly THEMES_DIR="${DOTFILES_DIR}/themes"
readonly TEMPLATES_DIR="${THEMES_DIR}/templates"
readonly ANALYSIS_DIR="${THEMES_DIR}/analysis"
readonly COLORS_CSV="${ANALYSIS_DIR}/colors.csv"
readonly CLUSTER_JSON="${ANALYSIS_DIR}/clusters.json"
readonly MAP_FILE="${THEMES_DIR}/wallpaper-map.conf"
readonly GROUPS_FILE="${THEMES_DIR}/groups.conf"

# ============================================================================
# Color math utilities (using awk for float math)
# ============================================================================

# Convert hex color to R G B (0-255)
hex_to_rgb() {
    local hex="${1#\#}"
    printf '%d %d %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# Convert R G B (0-255) to hex
rgb_to_hex() {
    printf '%02x%02x%02x' "$1" "$2" "$3"
}

# Convert RGB (0-255) to HSL (H:0-360, S:0-100, L:0-100) using awk
rgb_to_hsl() {
    local r="$1" g="$2" b="$3"
    awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN {
        r /= 255; g /= 255; b /= 255
        max = r; if (g > max) max = g; if (b > max) max = b
        min = r; if (g < min) min = g; if (b < min) min = b
        l = (max + min) / 2
        if (max == min) { h = 0; s = 0 }
        else {
            d = max - min
            s = (l > 0.5) ? d / (2 - max - min) : d / (max + min)
            if (max == r) h = (g - b) / d + (g < b ? 6 : 0)
            else if (max == g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h *= 60
        }
        printf "%.0f %.0f %.0f", h, s * 100, l * 100
    }'
}

# Convert HSL (H:0-360, S:0-100, L:0-100) to RGB (0-255) using awk
hsl_to_rgb() {
    local h="$1" s="$2" l="$3"
    awk -v h="$h" -v s="$s" -v l="$l" 'BEGIN {
        s /= 100; l /= 100
        if (s == 0) { r = g = b = l }
        else {
            q = (l < 0.5) ? l * (1 + s) : l + s - l * s
            p = 2 * l - q
            hk = h / 360
            # Red
            t = hk + 1/3; if (t < 0) t += 1; if (t > 1) t -= 1
            if (t < 1/6) r = p + (q - p) * 6 * t
            else if (t < 1/2) r = q
            else if (t < 2/3) r = p + (q - p) * (2/3 - t) * 6
            else r = p
            # Green
            t = hk; if (t < 0) t += 1; if (t > 1) t -= 1
            if (t < 1/6) g = p + (q - p) * 6 * t
            else if (t < 1/2) g = q
            else if (t < 2/3) g = p + (q - p) * (2/3 - t) * 6
            else g = p
            # Blue
            t = hk - 1/3; if (t < 0) t += 1; if (t > 1) t -= 1
            if (t < 1/6) b = p + (q - p) * 6 * t
            else if (t < 1/2) b = q
            else if (t < 2/3) b = p + (q - p) * (2/3 - t) * 6
            else b = p
        }
        printf "%.0f %.0f %.0f", r * 255, g * 255, b * 255
    }'
}

# Generate a hex color from HSL values
hsl_to_hex() {
    local rgb
    rgb="$(hsl_to_rgb "$1" "$2" "$3")"
    # shellcheck disable=SC2086
    rgb_to_hex $rgb
}

# Shift hue by degrees (wraps at 360)
hue_shift() {
    local h="$1" shift="$2"
    awk -v h="$h" -v s="$shift" 'BEGIN { h += s; while (h < 0) h += 360; while (h >= 360) h -= 360; printf "%.0f", h }'
}

# Clamp value between min and max
clamp() {
    local val="$1" min_v="$2" max_v="$3"
    awk -v v="$val" -v mn="$min_v" -v mx="$max_v" 'BEGIN { if (v < mn) v = mn; if (v > mx) v = mx; printf "%.0f", v }'
}

# Make a brighter variant of a hex color
brighten_hex() {
    local hex="$1" amount="${2:-15}"
    local rgb hsl h s l new_l
    rgb="$(hex_to_rgb "$hex")"
    # shellcheck disable=SC2086
    hsl="$(rgb_to_hsl $rgb)"
    read -r h s l <<< "$hsl"
    new_l="$(clamp "$((l + amount))" 0 100)"
    hsl_to_hex "$h" "$s" "$new_l"
}

# ============================================================================
# Phase 1: Color extraction (ImageMagick)
# ============================================================================

extract_colors() {
    local wallpaper="$1"
    local basename
    basename="$(basename "$wallpaper")"

    # Get luminance
    local luminance
    luminance="$(magick "$wallpaper" -resize 1x1! -format '%[fx:luminance]' info: 2>/dev/null)" || return 1

    # Get dominant color HSL
    local hsl_raw
    hsl_raw="$(magick "$wallpaper" -resize 200x200^ -colors 1 -depth 8 \
        -colorspace HSL -format '%[fx:p{0,0}.r*360] %[fx:p{0,0}.g] %[fx:p{0,0}.b]' info: 2>/dev/null)" || return 1

    # Get top 5 colors as hex
    local histogram
    histogram="$(magick "$wallpaper" -resize 200x200^ -colors 5 -depth 8 \
        -format '%c' histogram:info: 2>/dev/null)" || return 1

    # Parse histogram into hex colors with weights using awk
    local colors_data
    colors_data="$(printf '%s\n' "$histogram" | awk '
        match($0, /([0-9]+):.*\(([0-9]+),([0-9]+),([0-9]+)/, m) {
            printf "%02x%02x%02x:%s,", m[2], m[3], m[4], m[1]
        }
    ')"

    printf '%s|%s|%s|%s\n' "$basename" "$luminance" "$hsl_raw" "${colors_data%,}"
}

run_extraction() {
    mkdir -p "$ANALYSIS_DIR"
    printf '' > "$COLORS_CSV"

    local total count=0
    local -a wallpapers=()
    mapfile -d '' wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 2 -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \
    \) -print0 2>/dev/null)

    total="${#wallpapers[@]}"
    if [[ "$total" -eq 0 ]]; then
        printf 'No wallpapers found in %s\n' "$WALLPAPER_DIR" >&2
        return 1
    fi

    printf 'Analyzing %d wallpapers...\n' "$total"

    for wallpaper in "${wallpapers[@]}"; do
        (( count++ )) || true
        printf '\r[%d/%d] %s' "$count" "$total" "$(basename "$wallpaper")"

        local result
        if result="$(extract_colors "$wallpaper")"; then
            printf '%s\n' "$result" >> "$COLORS_CSV"
        else
            printf '\nWarning: Failed to analyze %s\n' "$(basename "$wallpaper")" >&2
        fi
    done
    printf '\nExtraction complete: %s\n' "$COLORS_CSV"
}

# ============================================================================
# Phase 2: Clustering (Python)
# ============================================================================

run_clustering() {
    if [[ ! -f "$COLORS_CSV" ]]; then
        printf 'Error: %s not found. Run extraction first.\n' "$COLORS_CSV" >&2
        return 1
    fi

    mkdir -p "$ANALYSIS_DIR"

    printf 'Clustering wallpapers into dynamic groups...\n'
    python3 "${DOTFILES_DIR}/scripts/cluster-wallpapers.py" \
        --csv "$COLORS_CSV" \
        --filter-current "$WALLPAPER_DIR" \
        > "$CLUSTER_JSON"

    # Print summary
    printf '\nGroup summary:\n'
    python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
print(f\"  Total groups: {data['k']}\")
for g in data['groups']:
    print(f\"  {g['name']:<25} {g['type']:<6} {g['size']:>3} wallpapers\")
" "$CLUSTER_JSON"
}

# ============================================================================
# Phase 3: Write wallpaper-map.conf from cluster JSON
# ============================================================================

run_mapping() {
    if [[ ! -f "$CLUSTER_JSON" ]]; then
        printf 'Error: %s not found. Run clustering first.\n' "$CLUSTER_JSON" >&2
        return 1
    fi

    {
        printf '# wallpaper-map.conf – Generated by generate-themes.sh\n'
        printf '# Format: filename=group-name\n'
        printf '# Generated: %s\n\n' "$(date -Iseconds)"

        python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
for group in data['groups']:
    for member in sorted(group['members']):
        print(f\"{member}={group['name']}\")
" "$CLUSTER_JSON"
    } > "$MAP_FILE"

    printf 'Wallpaper map written: %s\n' "$MAP_FILE"
}

# ============================================================================
# Phase 4: Generate theme files from templates
# ============================================================================

derive_palette() {
    local group_name="$1" group_type="$2" accent_h="$3" accent_s="$4" accent_l="$5"

    # Ensure accent saturation is vivid enough
    local adj_s
    adj_s="$(clamp "$accent_s" 45 85)"
    local adj_l
    if [[ "$group_type" == "dark" ]]; then
        adj_l="$(clamp "$accent_l" 55 75)"
    else
        adj_l="$(clamp "$accent_l" 40 60)"
    fi

    # Core accent colors
    local accent accent_secondary accent_bright
    accent="$(hsl_to_hex "$accent_h" "$adj_s" "$adj_l")"
    local sec_h
    sec_h="$(hue_shift "$accent_h" 40)"
    accent_secondary="$(hsl_to_hex "$sec_h" "$adj_s" "$adj_l")"
    accent_bright="$(brighten_hex "$accent" 12)"

    # Background and surface colors
    local bg_base bg_surface bg_overlay
    if [[ "$group_type" == "dark" ]]; then
        bg_base="$(hsl_to_hex "$accent_h" 15 12)"
        bg_surface="$(hsl_to_hex "$accent_h" 13 20)"
        bg_overlay="$(hsl_to_hex "$accent_h" 12 27)"
    else
        bg_base="$(hsl_to_hex "$accent_h" 20 95)"
        bg_surface="$(hsl_to_hex "$accent_h" 15 87)"
        bg_overlay="$(hsl_to_hex "$accent_h" 12 80)"
    fi

    # Text colors
    local text text_sub text_dim
    if [[ "$group_type" == "dark" ]]; then
        text="$(hsl_to_hex "$accent_h" 15 85)"
        text_sub="$(hsl_to_hex "$accent_h" 12 70)"
        text_dim="$(hsl_to_hex "$accent_h" 10 45)"
    else
        text="$(hsl_to_hex "$accent_h" 20 30)"
        text_sub="$(hsl_to_hex "$accent_h" 15 45)"
        text_dim="$(hsl_to_hex "$accent_h" 10 60)"
    fi

    # Shadow
    local shadow
    if [[ "$group_type" == "dark" ]]; then
        shadow="$(hsl_to_hex "$accent_h" 20 5)ee"
    else
        shadow="$(hsl_to_hex "$accent_h" 15 30)40"
    fi

    # ANSI colors – keep hue roles, adapt saturation/lightness
    local ansi_s ansi_l_normal ansi_l_bright
    if [[ "$group_type" == "dark" ]]; then
        ansi_s="$(clamp "$adj_s" 50 80)"
        ansi_l_normal=70
        ansi_l_bright=80
    else
        ansi_s="$(clamp "$adj_s" 50 80)"
        ansi_l_normal=45
        ansi_l_bright=55
    fi

    local red green yellow blue magenta cyan orange pink
    red="$(hsl_to_hex 0 "$ansi_s" "$ansi_l_normal")"
    green="$(hsl_to_hex 120 "$ansi_s" "$ansi_l_normal")"
    yellow="$(hsl_to_hex 45 "$ansi_s" "$ansi_l_normal")"
    blue="$(hsl_to_hex 220 "$ansi_s" "$ansi_l_normal")"
    magenta="$(hsl_to_hex 310 "$ansi_s" "$ansi_l_normal")"
    cyan="$(hsl_to_hex 175 "$ansi_s" "$ansi_l_normal")"
    orange="$(hsl_to_hex 25 "$ansi_s" "$ansi_l_normal")"
    pink="$(hsl_to_hex 330 "$ansi_s" "$ansi_l_bright")"

    local red_bright yellow_bright
    red_bright="$(brighten_hex "$red" 12)"
    yellow_bright="$(brighten_hex "$yellow" 12)"

    # Dunst transparency
    local transparency
    if [[ "$group_type" == "dark" ]]; then
        transparency=8
    else
        transparency=5
    fi

    # Extract RGB components for CSS rgba() values
    local bg_base_rgb accent_rgb accent_secondary_rgb accent_bright_rgb bg_surface_rgb red_rgb
    bg_base_rgb="$(hex_to_rgb "$bg_base")"
    accent_rgb="$(hex_to_rgb "$accent")"
    accent_secondary_rgb="$(hex_to_rgb "$accent_secondary")"
    accent_bright_rgb="$(hex_to_rgb "$accent_bright")"
    bg_surface_rgb="$(hex_to_rgb "$bg_surface")"
    red_rgb="$(hex_to_rgb "$red")"
    local yellow_rgb
    yellow_rgb="$(hex_to_rgb "$yellow")"

    local bg_base_r bg_base_g bg_base_b
    read -r bg_base_r bg_base_g bg_base_b <<< "$bg_base_rgb"
    local accent_r accent_g accent_b
    read -r accent_r accent_g accent_b <<< "$accent_rgb"
    local accent_sec_r accent_sec_g accent_sec_b
    read -r accent_sec_r accent_sec_g accent_sec_b <<< "$accent_secondary_rgb"
    local accent_bright_r accent_bright_g accent_bright_b
    read -r accent_bright_r accent_bright_g accent_bright_b <<< "$accent_bright_rgb"
    local bg_surface_r bg_surface_g bg_surface_b
    read -r bg_surface_r bg_surface_g bg_surface_b <<< "$bg_surface_rgb"
    local red_r red_g red_b
    read -r red_r red_g red_b <<< "$red_rgb"
    local yellow_r yellow_g yellow_b
    read -r yellow_r yellow_g yellow_b <<< "$yellow_rgb"

    # Output all variables as key=value pairs
    printf 'group_name=%s\n' "$group_name"
    printf 'accent=%s\n' "$accent"
    printf 'accent_secondary=%s\n' "$accent_secondary"
    printf 'accent_bright=%s\n' "$accent_bright"
    printf 'bg_base=%s\n' "$bg_base"
    printf 'bg_surface=%s\n' "$bg_surface"
    printf 'bg_overlay=%s\n' "$bg_overlay"
    printf 'text=%s\n' "$text"
    printf 'text_sub=%s\n' "$text_sub"
    printf 'text_dim=%s\n' "$text_dim"
    printf 'shadow=%s\n' "$shadow"
    printf 'red=%s\n' "$red"
    printf 'green=%s\n' "$green"
    printf 'yellow=%s\n' "$yellow"
    printf 'blue=%s\n' "$blue"
    printf 'magenta=%s\n' "$magenta"
    printf 'cyan=%s\n' "$cyan"
    printf 'orange=%s\n' "$orange"
    printf 'pink=%s\n' "$pink"
    printf 'red_bright=%s\n' "$red_bright"
    printf 'transparency=%s\n' "$transparency"
    printf 'bg_base_r=%s\n' "$bg_base_r"
    printf 'bg_base_g=%s\n' "$bg_base_g"
    printf 'bg_base_b=%s\n' "$bg_base_b"
    printf 'accent_r=%s\n' "$accent_r"
    printf 'accent_g=%s\n' "$accent_g"
    printf 'accent_b=%s\n' "$accent_b"
    printf 'bg_surface_r=%s\n' "$bg_surface_r"
    printf 'bg_surface_g=%s\n' "$bg_surface_g"
    printf 'bg_surface_b=%s\n' "$bg_surface_b"
    printf 'red_r=%s\n' "$red_r"
    printf 'red_g=%s\n' "$red_g"
    printf 'red_b=%s\n' "$red_b"
    printf 'yellow_r=%s\n' "$yellow_r"
    printf 'yellow_g=%s\n' "$yellow_g"
    printf 'yellow_b=%s\n' "$yellow_b"
    printf 'yellow_bright=%s\n' "$yellow_bright"
    # ANSI truecolor strings for fastfetch (format: 38;2;R;G;B)
    printf 'accent_ansi=38;2;%s;%s;%s\n' "$accent_r" "$accent_g" "$accent_b"
    printf 'accent_secondary_ansi=38;2;%s;%s;%s\n' "$accent_sec_r" "$accent_sec_g" "$accent_sec_b"
    printf 'accent_bright_ansi=38;2;%s;%s;%s\n' "$accent_bright_r" "$accent_bright_g" "$accent_bright_b"
}

render_template() {
    local template="$1" output="$2"
    shift 2

    # Read palette variables from stdin or arguments
    local content
    content="$(< "$template")"

    # Replace all {{placeholder}} with values from palette
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        content="${content//\{\{${key}\}\}/${value}}"
    done

    printf '%s\n' "$content" > "$output"
}

# Generate theme files for a single group from centroid data
generate_group_themes() {
    local group_name="$1" group_type="$2" accent_h="$3" accent_s="$4" accent_l="$5"

    printf 'Generating themes for group: %s (%s, H=%s S=%s L=%s)\n' \
        "$group_name" "$group_type" "$accent_h" "$accent_s" "$accent_l" >&2

    # Derive full palette
    local palette
    palette="$(derive_palette "$group_name" "$group_type" "$accent_h" "$accent_s" "$accent_l")"

    # Create group directory
    local group_dir="${THEMES_DIR}/${group_name}"
    mkdir -p "$group_dir"

    # Render each template
    printf '%s\n' "$palette" | render_template "${TEMPLATES_DIR}/hyprland.tpl" "${group_dir}/hyprland.conf"
    printf '%s\n' "$palette" | render_template "${TEMPLATES_DIR}/kitty.tpl" "${group_dir}/kitty.conf"
    printf '%s\n' "$palette" | render_template "${TEMPLATES_DIR}/waybar.tpl" "${group_dir}/waybar.css"
    printf '%s\n' "$palette" | render_template "${TEMPLATES_DIR}/wofi.tpl" "${group_dir}/wofi.css"
    printf '%s\n' "$palette" | render_template "${TEMPLATES_DIR}/dunst.tpl" "${group_dir}/dunst.conf"
    printf '%s\n' "$palette" | render_template "${TEMPLATES_DIR}/fastfetch.tpl" "${group_dir}/fastfetch.jsonc"

    # Return accent hex for groups.conf
    local accent_hex
    accent_hex="$(printf '%s\n' "$palette" | awk -F= '/^accent=/ { print $2; exit }')"
    printf '%s|%s|#%s\n' "$group_name" "$group_type" "$accent_hex"
}

# Remove theme directories that no longer exist in groups.conf
cleanup_stale_groups() {
    local -a current_groups=()

    # Read current group names from JSON
    if [[ -f "$CLUSTER_JSON" ]]; then
        mapfile -t current_groups < <(python3 -c "
import json, sys
for g in json.load(open(sys.argv[1]))['groups']:
    print(g['name'])
" "$CLUSTER_JSON")
    fi

    for dir in "${THEMES_DIR}"/*/; do
        [[ ! -d "$dir" ]] && continue
        local dirname
        dirname="$(basename "$dir")"
        [[ "$dirname" == "templates" || "$dirname" == "analysis" ]] && continue

        local found=false
        for g in "${current_groups[@]}"; do
            [[ "$g" == "$dirname" ]] && found=true && break
        done

        if [[ "$found" == false ]]; then
            printf 'Removing stale group directory: %s\n' "$dirname"
            rm -rf "$dir"
        fi
    done
}

run_generation() {
    if [[ ! -f "$CLUSTER_JSON" ]]; then
        printf 'Error: %s not found. Run clustering first.\n' "$CLUSTER_JSON" >&2
        return 1
    fi

    # Verify templates exist
    for tpl in hyprland kitty waybar wofi dunst fastfetch; do
        if [[ ! -f "${TEMPLATES_DIR}/${tpl}.tpl" ]]; then
            printf 'Error: Template not found: %s\n' "${TEMPLATES_DIR}/${tpl}.tpl" >&2
            return 1
        fi
    done

    printf '# groups.conf – Theme group metadata\n' > "$GROUPS_FILE"
    printf '# Format: name|type|accent_hex\n' >> "$GROUPS_FILE"
    printf '# Generated by generate-themes.sh\n\n' >> "$GROUPS_FILE"

    # Read group data from cluster JSON and generate themes
    while IFS='|' read -r name type h s l; do
        local entry
        entry="$(generate_group_themes "$name" "$type" "$h" "$s" "$l")"
        printf '%s\n' "$entry" >> "$GROUPS_FILE"
    done < <(python3 -c "
import json, sys
for g in json.load(open(sys.argv[1]))['groups']:
    print(f\"{g['name']}|{g['type']}|{g['centroid_h']}|{g['centroid_s']}|{g['centroid_l']}\")
" "$CLUSTER_JSON")

    cleanup_stale_groups

    printf '\nAll themes generated. Groups file: %s\n' "$GROUPS_FILE"
}

# ============================================================================
# Single wallpaper add (assigns to nearest existing cluster)
# ============================================================================

add_single() {
    local wallpaper="$1"

    if [[ ! -f "$wallpaper" ]]; then
        printf 'Error: File not found: %s\n' "$wallpaper" >&2
        return 1
    fi

    if [[ ! -f "$CLUSTER_JSON" ]]; then
        printf 'Error: No cluster data found. Run full pipeline first.\n' >&2
        return 1
    fi

    printf 'Analyzing: %s\n' "$(basename "$wallpaper")"
    local result
    result="$(extract_colors "$wallpaper")"

    # Append to CSV
    printf '%s\n' "$result" >> "$COLORS_CSV"

    # Assign to nearest cluster via Python (simple hue + luminance distance)
    local group
    group="$(python3 -c "
import json, sys, math

line = sys.argv[1]
parts = line.split('|')
luminance = float(parts[1])
hsl = parts[2].split()
hue = float(hsl[0])

is_light = luminance >= 0.45
theme_type = 'light' if is_light else 'dark'

data = json.load(open(sys.argv[2]))
best_name = data['groups'][0]['name']
best_dist = float('inf')

for g in data['groups']:
    if g['type'] != theme_type:
        continue
    # Circular hue distance
    dh = min(abs(g['centroid_h'] - hue), 360 - abs(g['centroid_h'] - hue))
    # Luminance distance (scaled)
    dl = abs(g['centroid_l'] / 100.0 - luminance) * 360
    dist = dh + dl * 0.5
    if dist < best_dist:
        best_dist = dist
        best_name = g['name']

print(best_name)
" "$result" "$CLUSTER_JSON")"

    # Append to map
    local filename
    filename="$(basename "$wallpaper")"
    printf '%s=%s\n' "$filename" "$group" >> "$MAP_FILE"

    printf 'Assigned: %s → %s\n' "$filename" "$group"
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Validate dependencies
    if ! command -v magick &>/dev/null; then
        printf 'Error: ImageMagick (magick) is required but not found.\n' >&2
        printf 'Install with: sudo pacman -S imagemagick\n' >&2
        return 1
    fi
    if ! command -v python3 &>/dev/null; then
        printf 'Error: python3 is required but not found.\n' >&2
        return 1
    fi

    case "${1:-}" in
        --recluster)
            printf '=== Re-clustering from existing analysis ===\n'
            run_clustering
            run_mapping
            run_generation
            ;;
        --remap)
            printf '=== Re-writing wallpaper map from clusters ===\n'
            run_mapping
            ;;
        --regenerate)
            printf '=== Re-generating theme files from clusters ===\n'
            run_generation
            ;;
        --add)
            if [[ -z "${2:-}" ]]; then
                printf 'Usage: %s --add <wallpaper-file>\n' "$(basename "$0")" >&2
                return 1
            fi
            add_single "$2"
            ;;
        "")
            printf '%s\n\n' '=== Full theme generation pipeline ==='
            printf '%s\n' '--- Phase 1: Color extraction ---'
            run_extraction
            printf '\n%s\n' '--- Phase 2: Clustering ---'
            run_clustering
            printf '\n%s\n' '--- Phase 3: Wallpaper mapping ---'
            run_mapping
            printf '\n%s\n' '--- Phase 4: Theme generation ---'
            run_generation
            printf '\n%s\n' '=== Done! ==='
            ;;
        *)
            printf 'Usage: %s [--recluster|--remap|--regenerate|--add <file>]\n' "$(basename "$0")" >&2
            return 1
            ;;
    esac
}

main "$@"

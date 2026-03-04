#!/usr/bin/env bash
# theme-toggle.sh – Switch between wallpaper-based color theme groups
# Usage:
#   theme-toggle.sh <group-name>        Apply a specific theme group
#   theme-toggle.sh --auto <wallpaper>  Auto-select theme based on wallpaper mapping
#   theme-toggle.sh --list              List available theme groups
#   theme-toggle.sh                     Cycle to next theme group

set -euo pipefail

readonly DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
readonly THEMES_DIR="${DOTFILES_DIR}/themes"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/current-theme"
readonly MAP_FILE="${THEMES_DIR}/wallpaper-map.conf"
readonly GROUPS_FILE="${THEMES_DIR}/groups.conf"

# Ensure state directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Read current theme group from state file
get_current_theme() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    elif [[ -f "$GROUPS_FILE" ]]; then
        # Use first available group as default
        grep -v '^#' "$GROUPS_FILE" | grep -v '^$' | head -1 | cut -d'|' -f1
    else
        printf 'blue-dark'
    fi
}

# Get theme type (dark/light) for a group from groups.conf
get_theme_type() {
    local group="$1"
    local line
    line="$(grep "^${group}|" "$GROUPS_FILE" 2>/dev/null)" || true
    if [[ -n "$line" ]]; then
        printf '%s' "$line" | cut -d'|' -f2
    else
        printf 'dark'
    fi
}

# Get all group names from groups.conf
get_all_groups() {
    grep -v '^#' "$GROUPS_FILE" | grep -v '^$' | cut -d'|' -f1
}

# Look up wallpaper -> group from mapping file
lookup_wallpaper_group() {
    local wallpaper_basename="$1"
    local group=""

    while IFS='=' read -r file grp; do
        # Skip comments and empty lines
        [[ "$file" =~ ^#.*$ || -z "$file" ]] && continue
        if [[ "$file" == "$wallpaper_basename" ]]; then
            group="$grp"
            break
        fi
    done < "$MAP_FILE"

    if [[ -n "$group" ]]; then
        printf '%s' "$group"
    elif [[ -f "$GROUPS_FILE" ]]; then
        # Fallback: use first available group
        grep -v '^#' "$GROUPS_FILE" | grep -v '^$' | head -1 | cut -d'|' -f1
    else
        printf 'blue-dark'
    fi
}

# Apply GTK and Qt theming based on dark/light type
apply_gtk_qt() {
    local theme_type="$1"

    local gtk_theme_name
    if [[ "$theme_type" == "dark" ]]; then
        gtk_theme_name="Arc-Darker"
    else
        gtk_theme_name="Arc-Lighter"
    fi

    # GTK via gsettings
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme 'Sweet-Rainbow' 2>/dev/null || true
        if [[ "$theme_type" == "dark" ]]; then
            gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Darker' 2>/dev/null || true
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Lighter' 2>/dev/null || true
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
        fi
    fi

    # GTK3 settings.ini
    local gtk3_dir="${CONFIG_DIR}/gtk-3.0"
    mkdir -p "$gtk3_dir"
    printf '[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=Sweet-Rainbow\n' \
        "$gtk_theme_name" > "${gtk3_dir}/settings.ini"

    # GTK4 settings.ini
    local gtk4_dir="${CONFIG_DIR}/gtk-4.0"
    mkdir -p "$gtk4_dir"
    printf '[Settings]\ngtk-theme-name=%s\n' \
        "$gtk_theme_name" > "${gtk4_dir}/settings.ini"

    # Qt theming via qt5ct + kvantum
    local kvantum_theme
    if [[ "$theme_type" == "dark" ]]; then
        kvantum_theme="KvArcDark"
    else
        kvantum_theme="KvArc"
    fi

    mkdir -p "${CONFIG_DIR}/Kvantum"
    printf '[General]\ntheme=%s\n' "$kvantum_theme" \
        > "${CONFIG_DIR}/Kvantum/kvantum.kvconfig"

    mkdir -p "${CONFIG_DIR}/qt5ct" "${CONFIG_DIR}/qt6ct"
    printf '[Appearance]\nstyle=kvantum\nicon_theme=Sweet-Rainbow\n\n[Fonts]\nfixed="JetBrainsMono Nerd Font,12,-1,5,50,0,0,0,0,0"\ngeneral="JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0"\n' \
        | tee "${CONFIG_DIR}/qt5ct/qt5ct.conf" > "${CONFIG_DIR}/qt6ct/qt6ct.conf"

    # KDE/Qt apps read icon theme from kdeglobals
    printf '[Icons]\nTheme=Sweet-Rainbow\n' > "${CONFIG_DIR}/kdeglobals"
}

# Apply a theme group
apply_theme() {
    local group="$1"
    local group_dir="${THEMES_DIR}/${group}"

    # Validate group directory exists
    if [[ ! -d "$group_dir" ]]; then
        printf 'Unknown theme group: %s\n' "$group" >&2
        return 1
    fi

    # Determine dark/light type
    local theme_type
    theme_type="$(get_theme_type "$group")"

    # Hyprland: symlink theme.conf
    local hypr_theme="${CONFIG_DIR}/hypr/theme.conf"
    if [[ -f "${group_dir}/hyprland.conf" ]]; then
        ln -sfn "${group_dir}/hyprland.conf" "$hypr_theme"
    else
        printf 'Warning: Hyprland theme not found: %s/hyprland.conf\n' "$group_dir" >&2
    fi

    # Kitty: symlink active theme
    local kitty_theme="${CONFIG_DIR}/kitty/themes/active.conf"
    mkdir -p "${CONFIG_DIR}/kitty/themes"
    if [[ -f "${group_dir}/kitty.conf" ]]; then
        ln -sfn "${group_dir}/kitty.conf" "$kitty_theme"
        pkill -USR1 kitty 2>/dev/null || true
    else
        printf 'Warning: Kitty theme not found: %s/kitty.conf\n' "$group_dir" >&2
    fi

    # Waybar: copy style (not symlink)
    local waybar_style="${CONFIG_DIR}/waybar/style.css"
    if [[ -f "${group_dir}/waybar.css" ]]; then
        cp "${group_dir}/waybar.css" "$waybar_style"
    else
        printf 'Warning: Waybar theme not found: %s/waybar.css\n' "$group_dir" >&2
    fi

    # Wofi: symlink style
    local wofi_style="${CONFIG_DIR}/wofi/style.css"
    if [[ -f "${group_dir}/wofi.css" ]]; then
        ln -sfn "${group_dir}/wofi.css" "$wofi_style"
    else
        printf 'Warning: Wofi theme not found: %s/wofi.css\n' "$group_dir" >&2
    fi

    # Dunst: symlink config and reload
    local dunst_conf="${CONFIG_DIR}/dunst/dunstrc"
    mkdir -p "${CONFIG_DIR}/dunst"
    if [[ -f "${group_dir}/dunst.conf" ]]; then
        ln -sfn "${group_dir}/dunst.conf" "$dunst_conf"
        pkill -SIGUSR2 dunst 2>/dev/null || true
    else
        printf 'Warning: Dunst theme not found: %s/dunst.conf\n' "$group_dir" >&2
    fi

    # Fastfetch: symlink config
    local fastfetch_conf="${CONFIG_DIR}/fastfetch/config.jsonc"
    mkdir -p "${CONFIG_DIR}/fastfetch"
    if [[ -f "${group_dir}/fastfetch.jsonc" ]]; then
        ln -sfn "${group_dir}/fastfetch.jsonc" "$fastfetch_conf"
    fi

    # GTK/Qt: apply dark or light based on theme type
    apply_gtk_qt "$theme_type"

    # Reload Hyprland
    if command -v hyprctl &>/dev/null; then
        hyprctl reload 2>/dev/null || true
    fi

    # Restart Waybar
    pkill waybar 2>/dev/null || true
    sleep 0.5
    waybar &>/dev/null &
    disown

    # Save current theme state
    printf '%s' "$group" > "$STATE_FILE"

    # Notify user
    if command -v notify-send &>/dev/null; then
        notify-send \
            --urgency low \
            --icon "preferences-desktop-theme" \
            "Theme: ${group}" "Type: ${theme_type}" 2>/dev/null || true
    fi

    printf 'Theme applied: %s (%s)\n' "$group" "$theme_type"
}

# List available theme groups
list_groups() {
    if [[ ! -f "$GROUPS_FILE" ]]; then
        printf 'No groups.conf found. Run generate-themes.sh first.\n' >&2
        return 1
    fi

    local current
    current="$(get_current_theme)"

    printf 'Available theme groups:\n'
    while IFS='|' read -r name type accent; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        local marker=""
        if [[ "$name" == "$current" ]]; then
            marker=" *"
        fi
        printf '  %-18s %-6s %s%s\n' "$name" "$type" "$accent" "$marker"
    done < "$GROUPS_FILE"
}

# Cycle to the next theme group
cycle_theme() {
    local current
    current="$(get_current_theme)"

    local -a groups=()
    while IFS='|' read -r name _; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        groups+=("$name")
    done < "$GROUPS_FILE"

    if [[ "${#groups[@]}" -eq 0 ]]; then
        printf 'No theme groups found.\n' >&2
        return 1
    fi

    # Find current index and advance
    local next_idx=0
    for i in "${!groups[@]}"; do
        if [[ "${groups[$i]}" == "$current" ]]; then
            next_idx=$(( (i + 1) % ${#groups[@]} ))
            break
        fi
    done

    apply_theme "${groups[$next_idx]}"
}

main() {
    case "${1:-}" in
        --auto)
            if [[ -z "${2:-}" ]]; then
                printf 'Usage: %s --auto <wallpaper-path>\n' "$(basename "$0")" >&2
                return 1
            fi
            if [[ ! -f "$MAP_FILE" ]]; then
                printf 'Warning: %s not found. Run generate-themes.sh first.\n' "$MAP_FILE" >&2
                return 1
            fi
            local wallpaper_basename
            wallpaper_basename="$(basename "$2")"
            local group
            group="$(lookup_wallpaper_group "$wallpaper_basename")"

            # Only switch if group changed
            local current
            current="$(get_current_theme)"
            if [[ "$current" != "$group" ]]; then
                apply_theme "$group"
            fi
            ;;
        --list)
            list_groups
            ;;
        "")
            cycle_theme
            ;;
        *)
            # Treat argument as group name
            apply_theme "$1"
            ;;
    esac
}

main "$@"

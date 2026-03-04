#!/usr/bin/env bash
# Description: GTK/Qt/Cursor/Icons Theme-System einrichten
# Severity: wichtig
# Depends: 02-install-packages
# Fix: Installiere qt5ct, qt6ct, kvantum, nwg-look und AUR-Themes

set -euo pipefail

module_run() {
    # Set environment variables for Qt theming in Hyprland config
    # (These are typically set in hyprland.conf via env directives)
    log_info "Verifying theming packages..."

    local -a theme_pkgs=(qt5ct qt6ct kvantum nwg-look)
    local all_installed=true
    for pkg in "${theme_pkgs[@]}"; do
        if ! pkg_installed "$pkg"; then
            log_warn "Missing theming package: $pkg"
            all_installed=false
        fi
    done

    if [[ "$all_installed" == "true" ]]; then
        log_ok "All theming packages installed."
    fi

    # Verify AUR themes
    local -a aur_themes=(bibata-cursor-theme-bin candy-icons-git sweet-folders-icons-git arc-gtk-theme)
    for pkg in "${aur_themes[@]}"; do
        if pkg_installed "$pkg"; then
            log_ok "AUR theme installed: $pkg"
        else
            log_warn "AUR theme missing: $pkg (install via module 02)"
        fi
    done

    # Link kvantum config if it exists
    local kvantum_src="${DOTFILES_DIR}/config/Kvantum"
    if [[ -d "$kvantum_src" ]]; then
        if link_is_correct "${CONFIG_DIR}/Kvantum" "$kvantum_src"; then
            log_ok "Already linked: Kvantum config"
        else
            link_config "$kvantum_src" "${CONFIG_DIR}/Kvantum"
        fi
    fi

    # Link qt5ct config if it exists
    local qt5ct_src="${DOTFILES_DIR}/config/qt5ct"
    if [[ -d "$qt5ct_src" ]]; then
        if link_is_correct "${CONFIG_DIR}/qt5ct" "$qt5ct_src"; then
            log_ok "Already linked: qt5ct config"
        else
            link_config "$qt5ct_src" "${CONFIG_DIR}/qt5ct"
        fi
    fi

    # Link qt6ct config if it exists
    local qt6ct_src="${DOTFILES_DIR}/config/qt6ct"
    if [[ -d "$qt6ct_src" ]]; then
        if link_is_correct "${CONFIG_DIR}/qt6ct" "$qt6ct_src"; then
            log_ok "Already linked: qt6ct config"
        else
            link_config "$qt6ct_src" "${CONFIG_DIR}/qt6ct"
        fi
    fi

    # Generate themes if the script exists
    local gen_script="${DOTFILES_DIR}/scripts/generate-themes.sh"
    if [[ -x "$gen_script" ]]; then
        log_info "Theme generation script available at: $gen_script"
        log_info "Run it manually to regenerate theme configs: $gen_script"
    fi

    # Apply default theme if no theme is active yet
    local default_group="blue-dark"
    local group_dir="${DOTFILES_DIR}/themes/${default_group}"
    local hypr_theme="${CONFIG_DIR}/hypr/theme.conf"

    if [[ ! -e "$hypr_theme" ]] && [[ -d "$group_dir" ]]; then
        log_info "No active theme found – applying default: ${default_group}"

        # Hyprland
        ln -sfn "${group_dir}/hyprland.conf" "$hypr_theme"

        # Kitty
        mkdir -p "${CONFIG_DIR}/kitty/themes"
        if [[ -f "${group_dir}/kitty.conf" ]]; then
            ln -sfn "${group_dir}/kitty.conf" "${CONFIG_DIR}/kitty/themes/active.conf"
        fi

        # Waybar (copy, not symlink – matches theme-toggle.sh behavior)
        if [[ -f "${group_dir}/waybar.css" ]]; then
            cp "${group_dir}/waybar.css" "${CONFIG_DIR}/waybar/style.css"
        fi

        # Wofi
        if [[ -f "${group_dir}/wofi.css" ]]; then
            ln -sfn "${group_dir}/wofi.css" "${CONFIG_DIR}/wofi/style.css"
        fi

        # Dunst
        mkdir -p "${CONFIG_DIR}/dunst"
        if [[ -f "${group_dir}/dunst.conf" ]]; then
            ln -sfn "${group_dir}/dunst.conf" "${CONFIG_DIR}/dunst/dunstrc"
        fi

        # Fastfetch
        mkdir -p "${CONFIG_DIR}/fastfetch"
        if [[ -f "${group_dir}/fastfetch.jsonc" ]]; then
            ln -sfn "${group_dir}/fastfetch.jsonc" "${CONFIG_DIR}/fastfetch/config.jsonc"
        fi

        log_ok "Default theme '${default_group}' applied."
    elif [[ -e "$hypr_theme" ]]; then
        log_ok "Theme already active: $(readlink -f "$hypr_theme" 2>/dev/null || echo "$hypr_theme")"
    fi

    # Set icon theme via gsettings (needed for Wayland/Hyprland GTK apps)
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme 'Sweet-Rainbow' 2>/dev/null || true
        log_ok "Icon theme set via gsettings: Sweet-Rainbow"
    fi

    log_ok "Theming setup complete."
}

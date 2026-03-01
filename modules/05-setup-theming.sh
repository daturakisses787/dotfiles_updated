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

    log_ok "Theming setup complete."
}

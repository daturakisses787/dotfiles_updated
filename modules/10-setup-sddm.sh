#!/usr/bin/env bash
# Description: SDDM Display-Manager mit Custom Theme einrichten
# Severity: wichtig
# Depends: 02-install-packages
# Fix: Installiere sddm und prüfe config/sddm/dotfiles-dark/

set -euo pipefail

module_run() {
    if ! pkg_installed sddm; then
        log_warn "sddm not installed. Install via module 02."
        return 1
    fi

    # Copy custom SDDM theme to system directory
    local theme_src="${DOTFILES_DIR}/config/sddm/dotfiles-dark"
    local theme_dst="/usr/share/sddm/themes/dotfiles-dark"

    if [[ -d "$theme_src" ]]; then
        if [[ -d "$theme_dst" ]] && diff -rq "$theme_src" "$theme_dst" &>/dev/null; then
            log_ok "SDDM theme already installed."
        else
            log_info "Installing custom SDDM theme..."
            run_cmd sudo cp -r "$theme_src" "$theme_dst"
            log_ok "SDDM theme installed to $theme_dst"
        fi
    else
        log_warn "SDDM theme source not found: $theme_src"
    fi

    # Copy wallpaper as SDDM background
    local wp_name="${SDDM_WALLPAPER:-arch-chan_to.png}"
    local wp_src="${DOTFILES_DIR}/wallpapers/${wp_name}"
    local bg_dst="${theme_dst}/background.png"

    if [[ -f "$wp_src" ]]; then
        if [[ -f "$bg_dst" ]] && diff -q "$wp_src" "$bg_dst" &>/dev/null; then
            log_ok "SDDM background already up to date."
        else
            log_info "Copying ${wp_name} as SDDM background..."
            run_cmd sudo cp "$wp_src" "$bg_dst"
            log_ok "SDDM background set to ${wp_name}."
        fi
    else
        log_warn "SDDM wallpaper not found: ${wp_src}"
        log_info "Set SDDM_WALLPAPER in install.sh or copy wallpapers first (module 07)."
    fi

    # Configure SDDM to use custom theme
    local sddm_conf="/etc/sddm.conf.d/theme.conf"
    local expected_content="[Theme]
Current=dotfiles-dark"

    if [[ -f "$sddm_conf" ]] && grep -q "Current=dotfiles-dark" "$sddm_conf" 2>/dev/null; then
        log_ok "SDDM already configured to use dotfiles-dark theme."
    else
        log_info "Configuring SDDM theme..."
        run_cmd sudo mkdir -p /etc/sddm.conf.d
        echo "$expected_content" | run_cmd sudo tee "$sddm_conf" > /dev/null
        log_ok "SDDM configured with dotfiles-dark theme."
    fi

    # Enable SDDM service
    if service_enabled sddm.service; then
        log_ok "sddm.service is already enabled."
    else
        log_info "Enabling sddm.service..."
        run_cmd sudo systemctl enable sddm.service
        log_ok "sddm.service enabled."
    fi

    log_ok "SDDM setup complete."
}

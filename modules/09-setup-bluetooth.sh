#!/usr/bin/env bash
# Description: Bluetooth-Dienst aktivieren
# Severity: wichtig
# Depends: 02-install-packages
# Fix: Installiere bluez, bluez-utils, blueman, pipewire-audio

set -euo pipefail

module_run() {
    # Verify bluetooth packages
    local -a bt_pkgs=(bluez bluez-utils blueman pipewire-audio)
    for pkg in "${bt_pkgs[@]}"; do
        if ! pkg_installed "$pkg"; then
            log_warn "Missing bluetooth package: $pkg"
        fi
    done

    # Install /etc/bluetooth/main.conf (Experimental + AutoEnable)
    local bt_conf_src="${DOTFILES_DIR}/system/bluetooth/main.conf"
    local bt_conf_dst="/etc/bluetooth/main.conf"
    if [[ -f "$bt_conf_src" ]]; then
        if [[ -f "$bt_conf_dst" ]] && diff -q "$bt_conf_src" "$bt_conf_dst" &>/dev/null; then
            log_ok "bluetooth main.conf already up to date."
        else
            log_info "Installing bluetooth main.conf..."
            run_cmd sudo cp "$bt_conf_src" "$bt_conf_dst"
            run_cmd sudo chmod 644 "$bt_conf_dst"
            log_ok "bluetooth main.conf installed."
        fi
    else
        log_warn "system/bluetooth/main.conf not found, skipping."
    fi

    # Enable and start bluetooth service
    if service_enabled bluetooth.service; then
        log_ok "bluetooth.service is already enabled."
    else
        log_info "Enabling bluetooth.service..."
        run_cmd sudo systemctl enable --now bluetooth.service
        log_ok "bluetooth.service enabled and started."
    fi

    log_ok "Bluetooth setup complete."
}

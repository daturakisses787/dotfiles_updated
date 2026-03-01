#!/usr/bin/env bash
# Description: Bluetooth-Dienst aktivieren
# Severity: wichtig
# Depends: 02-install-packages
# Fix: Installiere bluez, bluez-utils, blueman

set -euo pipefail

module_run() {
    # Verify bluetooth packages
    local -a bt_pkgs=(bluez bluez-utils blueman)
    for pkg in "${bt_pkgs[@]}"; do
        if ! pkg_installed "$pkg"; then
            log_warn "Missing bluetooth package: $pkg"
        fi
    done

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

#!/usr/bin/env bash
# Description: NVIDIA-Umgebungsvariablen und Treiber prüfen
# Severity: wichtig
# Depends: 02-install-packages
# Fix: Installiere nvidia-open, nvidia-utils, lib32-nvidia-utils

set -euo pipefail

module_run() {
    # Check NVIDIA packages
    local -a nvidia_pkgs=(nvidia-open nvidia-utils lib32-nvidia-utils mesa-utils)
    local all_installed=true

    for pkg in "${nvidia_pkgs[@]}"; do
        if pkg_installed "$pkg"; then
            log_ok "Installed: $pkg"
        else
            log_warn "Missing: $pkg"
            all_installed=false
        fi
    done

    if [[ "$all_installed" != "true" ]]; then
        log_warn "Some NVIDIA packages are missing. Install them via module 02."
    fi

    # Verify nvidia module is loaded
    if lsmod | grep -q "^nvidia"; then
        log_ok "NVIDIA kernel module is loaded."
    else
        log_warn "NVIDIA kernel module not loaded. A reboot may be required."
    fi

    # Check if nvidia-setup.sh script is available
    local setup_script="${DOTFILES_DIR}/scripts/nvidia-setup.sh"
    if [[ -x "$setup_script" ]]; then
        log_info "NVIDIA setup script available: $setup_script"
        log_info "Run it for additional NVIDIA configuration (modprobe, mkinitcpio)."
    fi

    # Environment variables are set in hyprland.conf (env = directives)
    log_info "NVIDIA env variables are configured in hypr/hyprland.conf."
    log_ok "NVIDIA setup check complete."
}

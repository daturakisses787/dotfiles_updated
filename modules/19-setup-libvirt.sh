#!/usr/bin/env bash
# Description: Libvirt/QEMU Virtualisierung einrichten
# Severity: optional
# Depends: 02-install-packages
# Fix: Installiere qemu-full, virt-manager, dnsmasq aus optionalen Paketen

set -euo pipefail

module_run() {
    local -a virt_pkgs=(qemu-full virt-manager virt-viewer dnsmasq)
    local all_installed=true

    for pkg in "${virt_pkgs[@]}"; do
        if pkg_installed "$pkg"; then
            log_ok "Installed: $pkg"
        else
            log_warn "Missing: $pkg (install via optional packages)"
            all_installed=false
        fi
    done

    if [[ "$all_installed" != "true" ]]; then
        log_info "Install missing packages via: ./install.sh --module=20-optional-packages"
        return 0
    fi

    # Enable libvirtd service
    if service_enabled libvirtd.service; then
        log_ok "libvirtd.service is already enabled."
    else
        log_info "Enabling libvirtd.service..."
        run_cmd sudo systemctl enable --now libvirtd.service
        log_ok "libvirtd.service enabled and started."
    fi

    # Add user to libvirt group
    if groups "$USER" | grep -q "libvirt"; then
        log_ok "User $USER is already in libvirt group."
    else
        log_info "Adding $USER to libvirt group..."
        run_cmd sudo usermod -aG libvirt "$USER"
        log_ok "Added $USER to libvirt group. Re-login required."
    fi

    # Set default network to autostart
    if sudo virsh net-info default &>/dev/null; then
        local autostart
        autostart="$(sudo virsh net-info default 2>/dev/null | grep -i autostart | awk '{print $2}')"
        if [[ "$autostart" == "yes" ]]; then
            log_ok "Default network already set to autostart."
        else
            run_cmd sudo virsh net-autostart default
            run_cmd sudo virsh net-start default 2>/dev/null || true
            log_ok "Default network configured."
        fi
    fi

    log_ok "Libvirt setup complete."
}

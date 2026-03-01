#!/usr/bin/env bash
# Description: GRUB-Theme installieren
# Severity: optional
# Fix: Prüfe ob GRUB installiert ist und ein Theme in themes/ vorhanden ist

set -euo pipefail

module_run() {
    if ! pkg_installed grub; then
        log_warn "GRUB not installed, skipping theme setup."
        return 0
    fi

    # Check for existing GRUB theme config
    local grub_default="/etc/default/grub"
    if [[ ! -f "$grub_default" ]]; then
        log_warn "GRUB config not found at $grub_default"
        return 0
    fi

    # Check current GRUB theme setting
    local current_theme
    current_theme="$(grep '^GRUB_THEME=' "$grub_default" 2>/dev/null | cut -d= -f2 | tr -d '"' || true)"

    if [[ -n "$current_theme" && -f "$current_theme" ]]; then
        log_ok "GRUB theme already configured: $current_theme"
    else
        log_info "No GRUB theme configured."
        log_info "To set a GRUB theme, edit $grub_default and set GRUB_THEME=<path>"
        log_info "Then run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    fi

    log_ok "GRUB theme check complete."
}

#!/usr/bin/env bash
# Description: WebHID-udev-Regeln für Web-Konfiguratoren einrichten (Keychron, Dark Project)
# Severity: wichtig
# Depends: (none)
# Fix: Prüfe udev/ Verzeichnis im Dotfiles-Repo
# Autorun: true

set -euo pipefail

module_run() {
    local udev_src="${DOTFILES_DIR}/udev/50-webhid.rules"
    local udev_dst="/etc/udev/rules.d/50-webhid.rules"

    if [[ ! -f "$udev_src" ]]; then
        log_warn "udev/50-webhid.rules not found in dotfiles, skipping."
        return 0
    fi

    # Check if the rule is already installed and identical
    if [[ -f "$udev_dst" ]] && diff -q "$udev_src" "$udev_dst" &>/dev/null; then
        log_ok "WebHID udev rule already installed."
    else
        log_info "Installing WebHID udev rule to ${udev_dst}..."
        run_cmd sudo cp "$udev_src" "$udev_dst"
        run_cmd sudo chmod 644 "$udev_dst"
        run_cmd sudo udevadm control --reload-rules
        run_cmd sudo udevadm trigger --subsystem-match=hidraw
        log_ok "WebHID udev rule installed and rules reloaded."
    fi
}

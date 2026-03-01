#!/usr/bin/env bash
# Description: System-Update (pacman -Syu)
# Severity: kritisch
# Fix: Stelle sicher, dass Internet verfügbar ist und die Pacman-Keyring aktuell ist

set -euo pipefail

module_run() {
    check_internet

    log_info "Running full system update..."
    run_cmd sudo pacman -Syu --noconfirm
    log_ok "System update complete."
}

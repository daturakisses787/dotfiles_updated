#!/usr/bin/env bash
# Description: Obsidian einrichten (manuell nach Installation)
# Severity: manual
# Autorun: false
# Fix: Installiere obsidian aus den optionalen Paketen

set -euo pipefail

module_run() {
    if pkg_installed obsidian; then
        log_ok "Obsidian is already installed."
    else
        log_info "Obsidian is not installed."
        log_info "Install it via: sudo pacman -S obsidian"
        log_info "Or run: ./install.sh --module=20-optional-packages"
    fi

    # Create default vault directory
    local vault_dir="${HOME}/Obsidian"
    if [[ -d "$vault_dir" ]]; then
        log_ok "Obsidian vault directory exists: $vault_dir"
    else
        ensure_dir "$vault_dir"
        log_ok "Created Obsidian vault directory: $vault_dir"
    fi

    log_ok "Obsidian setup complete."
}

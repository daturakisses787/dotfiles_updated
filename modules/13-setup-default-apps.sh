#!/usr/bin/env bash
# Description: Standard-Anwendungen (mimeapps.list) konfigurieren
# Severity: optional
# Depends: 03-link-configs
# Fix: Prüfe config/mimeapps.list

set -euo pipefail

module_run() {
    local mimeapps_src="${DOTFILES_DIR}/config/mimeapps.list"
    local mimeapps_dst="${CONFIG_DIR}/mimeapps.list"

    if [[ ! -f "$mimeapps_src" ]]; then
        log_warn "No mimeapps.list found in config/, skipping."
        return 0
    fi

    if link_is_correct "$mimeapps_dst" "$mimeapps_src"; then
        log_ok "mimeapps.list already linked."
    else
        link_config "$mimeapps_src" "$mimeapps_dst"
    fi

    # Update MIME database
    if cmd_exists update-desktop-database; then
        run_cmd update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
        log_ok "MIME database updated."
    fi

    log_ok "Default apps setup complete."
}

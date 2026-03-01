#!/usr/bin/env bash
# Description: Chromium Bookmarks importieren
# Severity: optional
# Depends: 02-install-packages
# Fix: Prüfe extras/chromium/Bookmarks

set -euo pipefail

module_run() {
    if ! pkg_installed chromium; then
        log_warn "Chromium not installed. Install via module 02."
        return 0
    fi

    local bookmarks_src="${DOTFILES_DIR}/extras/chromium/Bookmarks"
    local chromium_dir="${CONFIG_DIR}/chromium/Default"

    if [[ ! -f "$bookmarks_src" ]]; then
        log_warn "No bookmarks backup found at extras/chromium/Bookmarks"
        return 0
    fi

    ensure_dir "$chromium_dir"
    local bookmarks_dst="${chromium_dir}/Bookmarks"

    if [[ -f "$bookmarks_dst" ]] && file_matches "$bookmarks_src" "$bookmarks_dst"; then
        log_ok "Chromium bookmarks already up to date."
    else
        # Copy (not link) since Chromium rewrites this file
        run_cmd cp "$bookmarks_src" "$bookmarks_dst"
        log_ok "Chromium bookmarks imported."
    fi

    log_ok "Chromium setup complete."
}

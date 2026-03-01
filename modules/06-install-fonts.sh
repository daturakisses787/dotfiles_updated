#!/usr/bin/env bash
# Description: Schriftarten installieren und Font-Cache aktualisieren
# Severity: wichtig
# Depends: 02-install-packages
# Fix: Prüfe packages/fonts.txt und führe fc-cache -fv aus

set -euo pipefail

module_run() {
    local fonts_file="${DOTFILES_DIR}/packages/fonts.txt"

    if [[ ! -f "$fonts_file" ]]; then
        log_warn "No fonts.txt found, skipping."
        return 0
    fi

    local -a missing_fonts=()
    while IFS= read -r pkg; do
        if ! pkg_installed "$pkg"; then
            missing_fonts+=("$pkg")
        fi
    done < <(read_packages_from_file "$fonts_file")

    if [[ "${#missing_fonts[@]}" -gt 0 ]]; then
        log_info "Installing ${#missing_fonts[@]} font packages..."
        run_cmd sudo pacman -S --noconfirm --needed "${missing_fonts[@]}"
    else
        log_ok "All font packages already installed."
    fi

    # Rebuild font cache
    log_info "Rebuilding font cache..."
    run_cmd fc-cache -fv
    log_ok "Font setup complete."
}

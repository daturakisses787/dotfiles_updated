#!/usr/bin/env bash
# Description: Optionale Pakete installieren (Discord, Steam, OBS, etc.)
# Severity: optional
# Depends: 01-install-yay
# Fix: Prüfe packages/optional.txt

set -euo pipefail

module_run() {
    local optional_file="${DOTFILES_DIR}/packages/optional.txt"

    if [[ ! -f "$optional_file" ]]; then
        log_warn "No optional.txt found, skipping."
        return 0
    fi

    local -a missing_pkgs=()
    while IFS= read -r pkg; do
        if ! pkg_installed "$pkg"; then
            missing_pkgs+=("$pkg")
        fi
    done < <(read_packages_from_file "$optional_file")

    if [[ "${#missing_pkgs[@]}" -eq 0 ]]; then
        log_ok "All optional packages already installed."
        return 0
    fi

    log_info "Missing optional packages (${#missing_pkgs[@]}):"
    for pkg in "${missing_pkgs[@]}"; do
        log_info "  - $pkg"
    done

    log_info "Installing optional packages..."
    run_cmd sudo pacman -S --noconfirm --needed "${missing_pkgs[@]}"
    log_ok "Optional packages installed."
}

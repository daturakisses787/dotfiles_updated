#!/usr/bin/env bash
# Description: Pakete aus packages/ installieren
# Severity: kritisch
# Depends: 01-install-yay
# Fix: Prüfe Paketlisten in packages/ und stelle sicher, dass yay verfügbar ist

set -euo pipefail

module_run() {
    local pkg_dir="${DOTFILES_DIR}/packages"

    # Install official repo packages (everything except aur.txt and optional.txt)
    log_info "Collecting official packages..."
    local -a missing_pacman=()
    while IFS= read -r pkg; do
        if ! pkg_installed "$pkg"; then
            missing_pacman+=("$pkg")
        fi
    done < <(read_packages_from_dir "$pkg_dir" "^(aur|optional)\.txt$")

    if [[ "${#missing_pacman[@]}" -gt 0 ]]; then
        log_info "Installing ${#missing_pacman[@]} official packages..."
        run_cmd sudo pacman -S --noconfirm --needed "${missing_pacman[@]}"
        log_ok "Official packages installed."
    else
        log_ok "All official packages already installed."
    fi

    # Install AUR packages
    if [[ -f "${pkg_dir}/aur.txt" ]]; then
        require_cmd yay "Install yay first (module 01-install-yay)"

        log_info "Collecting AUR packages..."
        local -a missing_aur=()
        while IFS= read -r pkg; do
            if ! pkg_installed "$pkg"; then
                missing_aur+=("$pkg")
            fi
        done < <(read_packages_from_file "${pkg_dir}/aur.txt")

        if [[ "${#missing_aur[@]}" -gt 0 ]]; then
            log_info "Installing ${#missing_aur[@]} AUR packages..."
            run_cmd yay -S --noconfirm --needed "${missing_aur[@]}"
            log_ok "AUR packages installed."
        else
            log_ok "All AUR packages already installed."
        fi
    fi
}

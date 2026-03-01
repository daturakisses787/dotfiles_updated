#!/usr/bin/env bash
# Description: VSCode Extensions installieren
# Severity: optional
# Depends: 02-install-packages
# Fix: Installiere code (VSCode) und prüfe extras/vscode/extensions.txt

set -euo pipefail

module_run() {
    if ! cmd_exists code; then
        log_warn "VSCode (code) not found. Install via module 02."
        return 0
    fi

    local extensions_file="${DOTFILES_DIR}/extras/vscode/extensions.txt"
    if [[ ! -f "$extensions_file" ]]; then
        log_warn "No extensions.txt found at extras/vscode/"
        return 0
    fi

    # Get currently installed extensions
    local -a installed_extensions
    mapfile -t installed_extensions < <(code --list-extensions 2>/dev/null || true)

    local -a missing_extensions=()
    while IFS= read -r ext; do
        local found=false
        for installed in "${installed_extensions[@]}"; do
            if [[ "${installed,,}" == "${ext,,}" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" != "true" ]]; then
            missing_extensions+=("$ext")
        fi
    done < <(read_packages_from_file "$extensions_file")

    if [[ "${#missing_extensions[@]}" -gt 0 ]]; then
        log_info "Installing ${#missing_extensions[@]} VSCode extensions..."
        for ext in "${missing_extensions[@]}"; do
            run_cmd code --install-extension "$ext" --force
            log_ok "Installed extension: $ext"
        done
    else
        log_ok "All VSCode extensions already installed."
    fi

    log_ok "VSCode setup complete."
}

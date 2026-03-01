#!/usr/bin/env bash
# Description: AUR-Helper (yay) installieren
# Severity: kritisch
# Depends: 00-system-update
# Fix: Stelle sicher, dass base-devel und git installiert sind

set -euo pipefail

module_run() {
    if cmd_exists yay; then
        log_ok "yay is already installed."
        return 0
    fi

    log_info "Installing yay from AUR..."

    # Ensure dependencies
    for dep in git makepkg; do
        require_cmd "$dep" "Install base-devel and git first"
    done

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    run_cmd git clone https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"
    (
        cd "$tmp_dir/yay-bin"
        run_cmd makepkg -si --noconfirm
    )

    rm -rf "$tmp_dir"
    log_ok "yay installed successfully."
}

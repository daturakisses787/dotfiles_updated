#!/usr/bin/env bash
# Description: LoboGrubTheme installieren
# Severity: optional
# Depends: 02-install-packages
# Fix: Prüfe ob GRUB installiert ist und Internet verfügbar

set -euo pipefail

module_run() {
    if ! pkg_installed grub; then
        log_warn "GRUB not installed, skipping theme setup."
        return 0
    fi

    local grub_default="/etc/default/grub"
    if [[ ! -f "$grub_default" ]]; then
        log_warn "GRUB config not found at $grub_default"
        return 0
    fi

    local theme_dir="/boot/grub/themes/lobocorp"
    local theme_file="${theme_dir}/theme.txt"

    # Check if theme is already installed
    if [[ -d "$theme_dir" ]] && [[ -f "$theme_file" ]]; then
        log_ok "LoboGrubTheme already installed at $theme_dir"
    else
        log_info "Installing LoboGrubTheme..."
        local tmpdir
        tmpdir="$(mktemp -d)"
        run_cmd git clone --depth 1 https://github.com/rats-scamper/LoboGrubTheme.git "$tmpdir"
        if [[ "$DRY_RUN" != "true" ]]; then
            sudo mkdir -p /boot/grub/themes
            sudo cp -r "${tmpdir}/lobocorp" /boot/grub/themes/
            log_ok "LoboGrubTheme installed to $theme_dir"
        else
            log_info "[DRY-RUN] Would copy lobocorp/ to /boot/grub/themes/"
        fi
        rm -rf "$tmpdir"
    fi

    # Set GRUB_THEME in /etc/default/grub
    if grep -q "^GRUB_THEME=\"${theme_file}\"" "$grub_default" 2>/dev/null; then
        log_ok "GRUB_THEME already set."
    else
        log_info "Setting GRUB_THEME in $grub_default..."
        if grep -q '^GRUB_THEME=' "$grub_default" 2>/dev/null; then
            run_cmd sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${theme_file}\"|" "$grub_default"
        elif grep -q '^#GRUB_THEME=' "$grub_default" 2>/dev/null; then
            run_cmd sudo sed -i "s|^#GRUB_THEME=.*|GRUB_THEME=\"${theme_file}\"|" "$grub_default"
        else
            echo "GRUB_THEME=\"${theme_file}\"" | run_cmd sudo tee -a "$grub_default" > /dev/null
        fi
        log_ok "GRUB_THEME set to ${theme_file}"
    fi

    # Set GRUB_GFXMODE
    if grep -q '^GRUB_GFXMODE=1920x1080' "$grub_default" 2>/dev/null; then
        log_ok "GRUB_GFXMODE already set to 1920x1080."
    else
        log_info "Setting GRUB_GFXMODE=1920x1080..."
        if grep -q '^GRUB_GFXMODE=' "$grub_default" 2>/dev/null; then
            run_cmd sudo sed -i 's|^GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080|' "$grub_default"
        elif grep -q '^#GRUB_GFXMODE=' "$grub_default" 2>/dev/null; then
            run_cmd sudo sed -i 's|^#GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080|' "$grub_default"
        else
            echo 'GRUB_GFXMODE=1920x1080' | run_cmd sudo tee -a "$grub_default" > /dev/null
        fi
        log_ok "GRUB_GFXMODE set to 1920x1080."
    fi

    # Regenerate GRUB config
    log_info "Regenerating GRUB config..."
    run_cmd sudo grub-mkconfig -o /boot/grub/grub.cfg

    log_ok "GRUB theme setup complete."
}

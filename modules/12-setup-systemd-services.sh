#!/usr/bin/env bash
# Description: Systemd-User-Services einrichten (Bluetooth A2DP)
# Severity: optional
# Depends: 09-setup-bluetooth
# Fix: Prüfe systemd/ Verzeichnis und Bluetooth-Scripts

set -euo pipefail

module_run() {
    local systemd_src="${DOTFILES_DIR}/systemd"
    local bin_src="${systemd_src}/bin"

    # Link Bluetooth helper scripts to ~/.local/bin/
    if [[ -d "$bin_src" ]]; then
        ensure_dir "${HOME}/.local/bin"

        for script in "$bin_src"/*; do
            [[ -f "$script" ]] || continue
            local script_name
            script_name="$(basename "$script")"
            local dst="${HOME}/.local/bin/${script_name}"

            if link_is_correct "$dst" "$script"; then
                log_ok "Already linked: ${script_name}"
            else
                link_config "$script" "$dst"
                run_cmd chmod +x "$dst"
            fi
        done
    fi

    # Install user service
    local service_file="${systemd_src}/bt-teufel-a2dp.service"
    if [[ -f "$service_file" ]]; then
        local user_service_dir="${CONFIG_DIR}/systemd/user"
        ensure_dir "$user_service_dir"

        local dst="${user_service_dir}/bt-teufel-a2dp.service"
        if link_is_correct "$dst" "$service_file"; then
            log_ok "Already linked: bt-teufel-a2dp.service"
        else
            link_config "$service_file" "$dst"
        fi

        # Reload systemd user daemon
        run_cmd systemctl --user daemon-reload

        # Enable the service
        if user_service_enabled bt-teufel-a2dp.service; then
            log_ok "bt-teufel-a2dp.service already enabled."
        else
            log_info "Enabling bt-teufel-a2dp.service..."
            run_cmd systemctl --user enable bt-teufel-a2dp.service
            log_ok "bt-teufel-a2dp.service enabled."
        fi
    else
        log_info "No bt-teufel-a2dp.service found, skipping."
    fi

    log_ok "Systemd user services setup complete."
}

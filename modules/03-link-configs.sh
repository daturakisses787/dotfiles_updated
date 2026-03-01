#!/usr/bin/env bash
# Description: Konfigurationen nach ~/.config verlinken
# Severity: kritisch
# Depends: 02-install-packages
# Fix: Prüfe ob config/ im Dotfiles-Verzeichnis existiert

set -euo pipefail

module_run() {
    local src_config="${DOTFILES_DIR}/config"

    # Directories to symlink into ~/.config/
    local -a config_dirs=(
        hypr
        waybar
        kitty
        wofi
        dunst
        fastfetch
        btop
        rofi
        Thunar
        xfce4
    )

    for dir in "${config_dirs[@]}"; do
        local src="${src_config}/${dir}"
        local dst="${CONFIG_DIR}/${dir}"

        if [[ ! -d "$src" ]]; then
            log_warn "Source config not found, skipping: ${src}"
            continue
        fi

        if link_is_correct "$dst" "$src"; then
            log_ok "Already linked: ${dir}"
        else
            link_config "$src" "$dst"
        fi
    done

    # Single files to symlink
    local src_mimeapps="${src_config}/mimeapps.list"
    local dst_mimeapps="${CONFIG_DIR}/mimeapps.list"
    if [[ -f "$src_mimeapps" ]]; then
        if link_is_correct "$dst_mimeapps" "$src_mimeapps"; then
            log_ok "Already linked: mimeapps.list"
        else
            link_config "$src_mimeapps" "$dst_mimeapps"
        fi
    fi

    # Link scripts to ~/.local/bin/
    local scripts_dir="${DOTFILES_DIR}/scripts"
    if [[ -d "$scripts_dir" ]]; then
        ensure_dir "${HOME}/.local/bin"
        for script in "$scripts_dir"/*.sh "$scripts_dir"/*.py; do
            [[ -f "$script" ]] || continue
            local script_name
            script_name="$(basename "$script")"
            local dst="${HOME}/.local/bin/${script_name}"

            if link_is_correct "$dst" "$script"; then
                log_ok "Already linked: scripts/${script_name}"
            else
                link_config "$script" "$dst"
            fi
        done
    fi

    log_ok "Config linking complete."
}

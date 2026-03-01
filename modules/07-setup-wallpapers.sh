#!/usr/bin/env bash
# Description: Wallpaper-Verzeichnis und swww einrichten
# Severity: optional
# Depends: 02-install-packages
# Fix: Installiere swww und lege Wallpapers in wallpapers/ ab

set -euo pipefail

module_run() {
    # Ensure swww is installed
    if ! pkg_installed swww; then
        log_warn "swww not installed. Install via module 02."
        return 1
    fi
    log_ok "swww is installed."

    # Create wallpapers directory
    local wallpapers_dir="${DOTFILES_DIR}/wallpapers"
    ensure_dir "$wallpapers_dir"

    # Create .gitkeep if directory is empty
    if [[ -z "$(ls -A "$wallpapers_dir" 2>/dev/null)" ]]; then
        run_cmd touch "${wallpapers_dir}/.gitkeep"
        log_warn "Wallpapers directory is empty. Add your wallpaper images manually."
    else
        local count
        count="$(find "$wallpapers_dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.webp' \) | wc -l)"
        log_ok "Found ${count} wallpaper(s) in wallpapers/."
    fi

    # Link wallpaper scripts if they exist
    local -a wp_scripts=(wallpaper.sh wallpaper-picker.sh)
    for script in "${wp_scripts[@]}"; do
        local src="${DOTFILES_DIR}/scripts/${script}"
        local dst="${HOME}/.local/bin/${script}"
        if [[ -f "$src" ]]; then
            if link_is_correct "$dst" "$src"; then
                log_ok "Already linked: ${script}"
            else
                ensure_dir "${HOME}/.local/bin"
                link_config "$src" "$dst"
            fi
        fi
    done

    log_ok "Wallpaper setup complete."
}

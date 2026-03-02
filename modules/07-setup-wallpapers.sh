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

    # Check if wallpapers are already present
    local img_count
    img_count="$(find "$wallpapers_dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \) 2>/dev/null | wc -l)"

    if [[ "$img_count" -gt 0 ]]; then
        log_ok "Found ${img_count} wallpaper(s) in wallpapers/."
    elif [[ -n "${WALLPAPER_REPO:-}" ]]; then
        # Clone wallpaper repo into wallpapers directory
        log_info "Cloning wallpapers from ${WALLPAPER_REPO}..."
        local tmpdir
        tmpdir="$(mktemp -d)"
        run_cmd git clone --depth 1 "$WALLPAPER_REPO" "$tmpdir"
        # Copy image files only (skip .git and other metadata)
        if [[ "$DRY_RUN" != "true" ]]; then
            find "$tmpdir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \) -exec cp {} "$wallpapers_dir/" \;
            img_count="$(find "$wallpapers_dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \) | wc -l)"
            log_ok "Cloned ${img_count} wallpaper(s) from repository."
        else
            log_info "[DRY-RUN] Would copy wallpapers from cloned repo."
        fi
        rm -rf "$tmpdir"
    else
        run_cmd touch "${wallpapers_dir}/.gitkeep"
        log_warn "Wallpapers directory is empty."
        log_info "Set WALLPAPER_REPO in install.sh or copy wallpapers manually."
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

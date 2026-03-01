#!/usr/bin/env bash
# verify.sh – Post-installation verification for dotfiles_updated
# Checks: packages installed, symlinks correct, services active, theme system functional

set -euo pipefail

# ==============================================================================
# Setup
# ==============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR

readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Counters
PASS=0
FAIL=0
WARN=0
SKIP=0

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ==============================================================================
# Logging Helpers
# ==============================================================================

pass() { ((PASS++)); printf " %b✓%b %s\n" "$GREEN" "$NC" "$1"; }
fail() { ((FAIL++)); printf " %b✗%b %s\n" "$RED" "$NC" "$1"; }
warn() { ((WARN++)); printf " %b⚡%b %s\n" "$YELLOW" "$NC" "$1"; }
skip() { ((SKIP++)); printf " %b-%b %s\n" "$BLUE" "$NC" "$1"; }
title() { printf "\n%b%b=== %s ===%b\n" "$BOLD" "$CYAN" "$1" "$NC"; }

# ==============================================================================
# Check: Packages
# ==============================================================================

verify_packages() {
    title "Paket-Verifikation"

    local pkg_dir="${DOTFILES_DIR}/packages"
    if [[ ! -d "$pkg_dir" ]]; then
        fail "packages/ Verzeichnis nicht gefunden"
        return
    fi

    local total=0
    local missing=0

    for pkg_file in "$pkg_dir"/*.txt; do
        [[ -f "$pkg_file" ]] || continue
        local category
        category="$(basename "$pkg_file" .txt)"

        # Skip optional packages from strict verification
        if [[ "$category" == "optional" ]]; then
            skip "optional.txt – wird nicht strikt geprüft"
            continue
        fi

        while IFS= read -r pkg; do
            [[ -z "$pkg" || "$pkg" == \#* ]] && continue
            ((total++))
            if ! pacman -Qi "$pkg" &>/dev/null; then
                fail "${pkg} (${category}) nicht installiert"
                ((missing++))
            fi
        done < "$pkg_file"
    done

    if [[ "$missing" -eq 0 ]]; then
        pass "Alle ${total} Pflicht-Pakete installiert"
    else
        fail "${missing}/${total} Pakete fehlen"
    fi
}

# ==============================================================================
# Check: Config Symlinks
# ==============================================================================

verify_symlinks() {
    title "Symlink-Verifikation"

    local src_config="${DOTFILES_DIR}/config"

    # Config directories
    local -a config_dirs=(
        hypr waybar kitty wofi dunst fastfetch btop rofi Thunar xfce4
    )

    for dir in "${config_dirs[@]}"; do
        local src="${src_config}/${dir}"
        local dst="${CONFIG_DIR}/${dir}"

        if [[ ! -d "$src" ]]; then
            skip "${dir} – Quelle fehlt"
            continue
        fi

        if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
            pass "${dir} → korrekt verlinkt"
        elif [[ -L "$dst" ]]; then
            fail "${dir} → falsches Ziel: $(readlink "$dst")"
        elif [[ -d "$dst" ]]; then
            warn "${dir} → existiert als Verzeichnis (kein Symlink)"
        else
            fail "${dir} → fehlt"
        fi
    done

    # mimeapps.list
    local src_mimeapps="${src_config}/mimeapps.list"
    local dst_mimeapps="${CONFIG_DIR}/mimeapps.list"
    if [[ -f "$src_mimeapps" ]]; then
        if [[ -L "$dst_mimeapps" ]] && [[ "$(readlink -f "$dst_mimeapps")" == "$(readlink -f "$src_mimeapps")" ]]; then
            pass "mimeapps.list → korrekt verlinkt"
        else
            fail "mimeapps.list → nicht korrekt verlinkt"
        fi
    fi

    # Scripts in ~/.local/bin/
    local scripts_dir="${DOTFILES_DIR}/scripts"
    if [[ -d "$scripts_dir" ]]; then
        local scripts_ok=0
        local scripts_missing=0
        for script in "$scripts_dir"/*.sh "$scripts_dir"/*.py; do
            [[ -f "$script" ]] || continue
            local name
            name="$(basename "$script")"
            local dst="${HOME}/.local/bin/${name}"
            if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$script")" ]]; then
                ((scripts_ok++))
            else
                fail "Script ${name} → nicht verlinkt in ~/.local/bin/"
                ((scripts_missing++))
            fi
        done
        if [[ "$scripts_missing" -eq 0 ]]; then
            pass "Alle ${scripts_ok} Scripts korrekt verlinkt"
        fi
    fi

    # Systemd bin scripts
    local systemd_bin="${DOTFILES_DIR}/systemd/bin"
    if [[ -d "$systemd_bin" ]]; then
        for script in "$systemd_bin"/*; do
            [[ -f "$script" ]] || continue
            local name
            name="$(basename "$script")"
            local dst="${HOME}/.local/bin/${name}"
            if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$script")" ]]; then
                pass "systemd/bin/${name} → korrekt verlinkt"
            else
                fail "systemd/bin/${name} → nicht verlinkt"
            fi
        done
    fi
}

# ==============================================================================
# Check: Services
# ==============================================================================

verify_services() {
    title "Service-Verifikation"

    # System services
    local -a system_services=(bluetooth NetworkManager sddm)
    for svc in "${system_services[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            pass "${svc}.service enabled"
        else
            warn "${svc}.service nicht enabled"
        fi
    done

    # User services
    local service_file="${DOTFILES_DIR}/systemd/bt-teufel-a2dp.service"
    if [[ -f "$service_file" ]]; then
        if systemctl --user is-enabled bt-teufel-a2dp.service &>/dev/null; then
            pass "bt-teufel-a2dp.service (user) enabled"
        else
            warn "bt-teufel-a2dp.service (user) nicht enabled"
        fi

        # Check symlink
        local dst="${CONFIG_DIR}/systemd/user/bt-teufel-a2dp.service"
        if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$service_file")" ]]; then
            pass "bt-teufel-a2dp.service → korrekt verlinkt"
        else
            fail "bt-teufel-a2dp.service → nicht verlinkt"
        fi
    fi
}

# ==============================================================================
# Check: Shell Setup
# ==============================================================================

verify_shell() {
    title "Shell-Verifikation"

    # ZSH as default shell
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current_shell" == *"zsh"* ]]; then
        pass "Default-Shell: zsh"
    else
        fail "Default-Shell ist ${current_shell}, nicht zsh"
    fi

    # Oh-My-Zsh
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        pass "Oh-My-Zsh installiert"
    else
        fail "Oh-My-Zsh nicht gefunden"
    fi

    # Powerlevel10k
    if [[ -d "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
        pass "Powerlevel10k installiert"
    else
        fail "Powerlevel10k nicht gefunden"
    fi
}

# ==============================================================================
# Check: Theme System
# ==============================================================================

verify_themes() {
    title "Theme-System-Verifikation"

    local themes_dir="${DOTFILES_DIR}/themes"

    # groups.conf
    if [[ -f "${themes_dir}/groups.conf" ]]; then
        pass "groups.conf vorhanden"
    else
        fail "groups.conf fehlt"
        return
    fi

    # Verify 7 theme groups
    local group_count
    group_count="$(grep -c '^[^#]' "${themes_dir}/groups.conf" | tr -d ' ')"
    if [[ "$group_count" -eq 7 ]]; then
        pass "7 Theme-Gruppen definiert"
    else
        fail "Erwartet 7 Gruppen, gefunden: ${group_count}"
    fi

    # Check each group directory exists
    while IFS='|' read -r name type _accent; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        if [[ -d "${themes_dir}/${name}" ]]; then
            pass "Gruppe ${name} (${type}) vorhanden"
        else
            fail "Gruppe ${name} – Verzeichnis fehlt"
        fi
    done < "${themes_dir}/groups.conf"

    # wallpaper-map.conf
    if [[ -f "${themes_dir}/wallpaper-map.conf" ]]; then
        pass "wallpaper-map.conf vorhanden"
    else
        warn "wallpaper-map.conf fehlt"
    fi

    # Templates
    local -a expected_templates=(dunst.tpl fastfetch.tpl hyprland.tpl kitty.tpl waybar.tpl wofi.tpl)
    local templates_ok=true
    for tpl in "${expected_templates[@]}"; do
        if [[ ! -f "${themes_dir}/templates/${tpl}" ]]; then
            fail "Template fehlt: ${tpl}"
            templates_ok=false
        fi
    done
    if [[ "$templates_ok" == true ]]; then
        pass "Alle 6 Theme-Templates vorhanden"
    fi

    # Key scripts
    if [[ -f "${DOTFILES_DIR}/scripts/generate-themes.sh" ]]; then
        pass "generate-themes.sh vorhanden"
    else
        fail "generate-themes.sh fehlt"
    fi

    if [[ -f "${DOTFILES_DIR}/scripts/theme-toggle.sh" ]]; then
        pass "theme-toggle.sh vorhanden"
    else
        fail "theme-toggle.sh fehlt"
    fi
}

# ==============================================================================
# Check: NVIDIA
# ==============================================================================

verify_nvidia() {
    title "NVIDIA-Verifikation"

    if command -v nvidia-smi &>/dev/null; then
        pass "nvidia-smi verfügbar"
        if nvidia-smi &>/dev/null; then
            pass "NVIDIA-Treiber funktionsfähig"
        else
            fail "nvidia-smi gibt Fehler zurück"
        fi
    else
        skip "nvidia-smi nicht installiert – keine NVIDIA-GPU?"
    fi
}

# ==============================================================================
# Check: Repository Integrity
# ==============================================================================

verify_repo() {
    title "Repository-Integrität"

    # Key directories
    local -a required_dirs=(lib modules packages config scripts themes systemd extras wallpapers)
    for dir in "${required_dirs[@]}"; do
        if [[ -d "${DOTFILES_DIR}/${dir}" ]]; then
            pass "${dir}/ vorhanden"
        else
            fail "${dir}/ fehlt"
        fi
    done

    # Key files
    local -a required_files=(install.sh verify.sh README.md CLAUDE.md .gitignore)
    for file in "${required_files[@]}"; do
        if [[ -f "${DOTFILES_DIR}/${file}" ]]; then
            pass "${file} vorhanden"
        else
            fail "${file} fehlt"
        fi
    done

    # Module count
    local mod_count
    mod_count="$(find "${DOTFILES_DIR}/modules" -name '[0-9]*.sh' -type f | wc -l)"
    if [[ "$mod_count" -eq 21 ]]; then
        pass "21 Module vorhanden"
    else
        warn "Erwartet 21 Module, gefunden: ${mod_count}"
    fi

    # Package list count
    local pkg_count
    pkg_count="$(find "${DOTFILES_DIR}/packages" -name '*.txt' -type f | wc -l)"
    if [[ "$pkg_count" -eq 11 ]]; then
        pass "11 Paketlisten vorhanden"
    else
        warn "Erwartet 11 Paketlisten, gefunden: ${pkg_count}"
    fi
}

# ==============================================================================
# Summary
# ==============================================================================

print_summary() {
    printf "\n%b%b══════════════════════════════════════════%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b%b       VERIFIKATIONS-ZUSAMMENFASSUNG%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b%b══════════════════════════════════════════%b\n\n" "$BOLD" "$CYAN" "$NC"

    printf " %b✓%b Bestanden:   %d\n" "$GREEN" "$NC" "$PASS"
    printf " %b✗%b Fehlgeschlagen: %d\n" "$RED" "$NC" "$FAIL"
    printf " %b⚡%b Warnungen:   %d\n" "$YELLOW" "$NC" "$WARN"
    printf " %b-%b Übersprungen: %d\n" "$BLUE" "$NC" "$SKIP"

    local total=$((PASS + FAIL + WARN + SKIP))
    printf "\n Gesamt: %d Prüfungen\n" "$total"

    if [[ "$FAIL" -eq 0 ]]; then
        printf "\n %b%bAlle Prüfungen bestanden!%b\n" "$BOLD" "$GREEN" "$NC"
        return 0
    else
        printf "\n %b%b%d Prüfungen fehlgeschlagen.%b\n" "$BOLD" "$RED" "$FAIL" "$NC"
        printf " Führe './install.sh' aus um fehlende Konfigurationen zu installieren.\n"
        return 1
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    printf "%b%bDotfiles Verification%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b━━━━━━━━━━━━━━━━━━━━━%b\n" "$BLUE" "$NC"

    verify_repo
    verify_packages
    verify_symlinks
    verify_services
    verify_shell
    verify_themes
    verify_nvidia

    print_summary
}

main "$@"

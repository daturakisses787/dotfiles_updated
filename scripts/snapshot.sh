#!/usr/bin/env bash
# snapshot.sh – Export current system state into the dotfiles repo (extras/)
# Usage: ./scripts/snapshot.sh [--all] [--chromium] [--claude] [--vscode] [--obsidian]

set -euo pipefail

readonly DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
readonly EXTRAS_DIR="${DOTFILES_DIR}/extras"

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_ok()   { printf "%b✓%b %s\n" "$GREEN"  "$NC" "$1"; }
log_info() { printf "%b→%b %s\n" "$BLUE"   "$NC" "$1"; }
log_warn() { printf "%b⚡%b %s\n" "$YELLOW" "$NC" "$1"; }
log_err()  { printf "%b✗%b %s\n" "$RED"    "$NC" "$1"; }

# ------------------------------------------------------------------------------
snapshot_chromium() {
    log_info "Snapshot: Chromium Bookmarks"
    local src="$HOME/.config/chromium/Default/Bookmarks"
    local dst="${EXTRAS_DIR}/chromium/Bookmarks"

    if [[ ! -f "$src" ]]; then
        log_warn "Chromium Bookmarks nicht gefunden: $src"
        return 0
    fi

    mkdir -p "${EXTRAS_DIR}/chromium"
    cp "$src" "$dst"
    log_ok "Bookmarks gespeichert → $dst"
}

# ------------------------------------------------------------------------------
snapshot_claude() {
    log_info "Snapshot: Claude Konfiguration"
    local src_dir="$HOME/.claude"
    local dst_dir="${EXTRAS_DIR}/claude"

    mkdir -p "$dst_dir"

    local files=("CLAUDE.md" "settings.json" "settings.local.json")
    for f in "${files[@]}"; do
        if [[ -f "${src_dir}/${f}" ]]; then
            cp "${src_dir}/${f}" "${dst_dir}/${f}"
            log_ok "Gespeichert: $f"
        else
            log_warn "Nicht gefunden: ${src_dir}/${f}"
        fi
    done
}

# ------------------------------------------------------------------------------
snapshot_vscode() {
    log_info "Snapshot: VS Code"
    local dst_dir="${EXTRAS_DIR}/vscode"
    mkdir -p "$dst_dir"

    # Find VS Code binary
    local code_bin=""
    for bin in code code-oss codium; do
        if command -v "$bin" &>/dev/null; then
            code_bin="$bin"
            break
        fi
    done

    if [[ -n "$code_bin" ]]; then
        log_info "Exportiere Extensions mit: $code_bin"
        "$code_bin" --list-extensions > "${dst_dir}/extensions.txt"
        log_ok "Extensions gespeichert → ${dst_dir}/extensions.txt"
    else
        log_warn "Kein VS Code Binary gefunden (code/code-oss/codium). Extensions übersprungen."
    fi

    # mcp.json
    local mcp_src="$HOME/.config/Code/User/mcp.json"
    if [[ -f "$mcp_src" ]]; then
        cp "$mcp_src" "${dst_dir}/mcp.json"
        log_ok "mcp.json gespeichert"
    fi
}

# ------------------------------------------------------------------------------
snapshot_obsidian() {
    log_info "Snapshot: Obsidian Plugins"
    local vault="${HOME}/ObsidianVault"

    if [[ ! -d "${vault}/.obsidian/plugins" ]]; then
        log_warn "Keine Obsidian Plugins gefunden in ${vault}/.obsidian/plugins"
        return 0
    fi

    local dst="${EXTRAS_DIR}/obsidian/plugins"
    mkdir -p "$dst"
    cp -r "${vault}/.obsidian/plugins/." "$dst/"
    log_ok "Obsidian Plugins gespeichert → $dst"
}

# ------------------------------------------------------------------------------
show_help() {
    printf "Usage: %s [OPTIONS]\n\n" "$(basename "$0")"
    printf "Exportiert den aktuellen Systemzustand in extras/\n\n"
    printf "Optionen:\n"
    printf "  --all        Alle Snapshots\n"
    printf "  --chromium   Chromium Bookmarks\n"
    printf "  --claude     Claude Konfiguration\n"
    printf "  --vscode     VS Code Extensions + mcp.json\n"
    printf "  --obsidian   Obsidian Plugins aus ~/ObsidianVault\n"
    printf "  --help       Diese Hilfe\n"
}

# ------------------------------------------------------------------------------
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local do_chromium=false do_claude=false do_vscode=false do_obsidian=false

    for arg in "$@"; do
        case "$arg" in
            --all)      do_chromium=true; do_claude=true; do_vscode=true; do_obsidian=true ;;
            --chromium) do_chromium=true ;;
            --claude)   do_claude=true ;;
            --vscode)   do_vscode=true ;;
            --obsidian) do_obsidian=true ;;
            --help|-h)  show_help; exit 0 ;;
            *) log_err "Unbekanntes Argument: $arg"; show_help; exit 1 ;;
        esac
    done

    [[ "$do_chromium" == "true" ]] && snapshot_chromium
    [[ "$do_claude"   == "true" ]] && snapshot_claude
    [[ "$do_vscode"   == "true" ]] && snapshot_vscode
    [[ "$do_obsidian" == "true" ]] && snapshot_obsidian

    printf "\n%b✓ Snapshot abgeschlossen.%b\n" "$GREEN" "$NC"
    printf "Vergiss nicht: git add extras/ && git commit -m 'chore: update snapshots'\n"
}

main "$@"

#!/usr/bin/env bash
# install.sh – Dotfiles Installation Orchestrator
# EndeavourOS + Hyprland Setup
# Usage: ./install.sh [--module=<name>] [--skip=<name,name>] [--dry-run] [--help]

set -euo pipefail

# ==============================================================================
# Constants & Variables
# ==============================================================================

# Self-locate: works regardless of where the repo is cloned
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR
export DOTFILES_DIR

readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
export CONFIG_DIR

readonly LOG_FILE="${DOTFILES_DIR}/install.log"
export LOG_FILE

BACKUP_DIR="${HOME}/.config/backup/$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_DIR
export BACKUP_DIR

DRY_RUN="${DRY_RUN:-false}"
export DRY_RUN

# Wallpaper repository – cloned by module 07
WALLPAPER_REPO="${WALLPAPER_REPO:-https://github.com/daturakisses787/wallpapers.git}"
export WALLPAPER_REPO

# SDDM login background wallpaper (filename inside wallpapers/)
SDDM_WALLPAPER="${SDDM_WALLPAPER:-arch-chan_to.png}"
export SDDM_WALLPAPER

SELECTED_MODULE=""
SKIP_MODULES=""

# Failed module tracking
declare -a FAILED_MODULES=()

# ==============================================================================
# Load Libraries
# ==============================================================================

# shellcheck source=lib/common.sh
source "${DOTFILES_DIR}/lib/common.sh"
# shellcheck source=lib/checks.sh
source "${DOTFILES_DIR}/lib/checks.sh"
# shellcheck source=lib/idempotent.sh
source "${DOTFILES_DIR}/lib/idempotent.sh"

# ==============================================================================
# Module Discovery & Execution
# ==============================================================================

# Parse module metadata from comment headers
# Expected format: # Description: Some text
module_get_meta() {
    local file="$1"
    local key="$2"
    grep -m1 "^# ${key}:" "$file" 2>/dev/null | sed "s/^# ${key}:[[:space:]]*//" || true
}

# Discover all modules sorted by numeric prefix
discover_modules() {
    local modules_dir="${DOTFILES_DIR}/modules"
    if [[ ! -d "$modules_dir" ]]; then
        log_err "Modules directory not found: $modules_dir"
        exit 1
    fi

    for f in "$modules_dir"/[0-9]*.sh; do
        [[ -f "$f" ]] || continue
        basename "$f" .sh
    done | sort
}

# Extract human-readable module name (strip numeric prefix)
module_display_name() {
    local mod="$1"
    echo "${mod#[0-9]*-}"
}

# Check if a module should be skipped
module_is_skipped() {
    local mod_name="$1"
    local display_name
    display_name="$(module_display_name "$mod_name")"

    if [[ -z "$SKIP_MODULES" ]]; then
        return 1
    fi

    # Check against both full name (01-install-yay) and display name (install-yay)
    IFS=',' read -ra skip_list <<< "$SKIP_MODULES"
    for skip in "${skip_list[@]}"; do
        skip="$(echo "$skip" | xargs)" # trim whitespace
        if [[ "$mod_name" == "$skip" || "$display_name" == "$skip" ]]; then
            return 0
        fi
    done
    return 1
}

# Run a single module safely – catch failures, log them, continue
run_module_safe() {
    local mod_name="$1"
    local mod_file="${DOTFILES_DIR}/modules/${mod_name}.sh"

    if [[ ! -f "$mod_file" ]]; then
        log_err "Module file not found: $mod_file"
        FAILED_MODULES+=("$mod_name")
        return 0
    fi

    if module_is_skipped "$mod_name"; then
        log_warn "Skipping module: $mod_name"
        return 0
    fi

    # Skip manual modules unless explicitly selected via --module=
    local autorun
    autorun="$(module_get_meta "$mod_file" "Autorun")"
    if [[ "$autorun" == "false" && -z "$SELECTED_MODULE" ]]; then
        log_info "Skipping manual module: $mod_name (run with --module=$mod_name)"
        return 0
    fi

    local description
    description="$(module_get_meta "$mod_file" "Description")"
    log_title "${description:-$mod_name}"

    # Source module and run its module_run function
    (
        # shellcheck source=/dev/null
        source "$mod_file"
        if declare -f module_run &>/dev/null; then
            module_run
        else
            log_err "Module $mod_name does not define module_run()"
            exit 1
        fi
    )

    local exit_code=$?
    if [[ "$exit_code" -ne 0 ]]; then
        FAILED_MODULES+=("$mod_name")
        local severity
        severity="$(module_get_meta "$mod_file" "Severity")"
        log_err "Module '${mod_name}' failed (exit code: $exit_code) [${severity:-unknown}]"
        local hint
        hint="$(module_get_meta "$mod_file" "Fix")"
        [[ -n "$hint" ]] && log_info "Fix: $hint"
    fi

    return 0
}

# ==============================================================================
# Run All Modules
# ==============================================================================

run_all_modules() {
    local modules
    mapfile -t modules < <(discover_modules)

    if [[ "${#modules[@]}" -eq 0 ]]; then
        log_err "No modules found in ${DOTFILES_DIR}/modules/"
        exit 1
    fi

    log_info "Found ${#modules[@]} modules to run."

    for mod in "${modules[@]}"; do
        run_module_safe "$mod"
    done
}

# ==============================================================================
# Summary
# ==============================================================================

print_summary() {
    local modules
    mapfile -t modules < <(discover_modules)
    local total_modules="${#modules[@]}"
    local failed_count="${#FAILED_MODULES[@]}"
    local success_count=$((total_modules - failed_count))

    printf "\n%b%b══════════════════════════════════════════%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b%b       INSTALLATIONS-ZUSAMMENFASSUNG%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b%b══════════════════════════════════════════%b\n\n" "$BOLD" "$CYAN" "$NC"

    printf "%b✓%b %d/%d Module erfolgreich\n" "$GREEN" "$NC" "$success_count" "$total_modules"

    if [[ "$failed_count" -eq 0 ]]; then
        printf "%b✓%b Alle Module erfolgreich abgeschlossen!\n" "$GREEN" "$NC"
        return 0
    fi

    printf "%b✗%b %d Module fehlgeschlagen:\n\n" "$RED" "$NC" "$failed_count"

    local has_critical=false
    for mod in "${FAILED_MODULES[@]}"; do
        local mod_file="${DOTFILES_DIR}/modules/${mod}.sh"
        local severity
        severity="$(module_get_meta "$mod_file" "Severity")"
        local color="$NC"
        case "${severity:-optional}" in
            kritisch) color="$RED"; has_critical=true ;;
            wichtig)  color="$YELLOW" ;;
            optional) color="$BLUE" ;;
        esac

        printf "  %b[%s]%b %s\n" "$color" "${severity:-unknown}" "$NC" "$mod"

        local hint
        hint="$(module_get_meta "$mod_file" "Fix")"
        [[ -n "$hint" ]] && printf "           → %s\n" "$hint"
    done

    if [[ "$has_critical" == "true" ]]; then
        printf "\n%b⚠  ACHTUNG: Kritische Module sind fehlgeschlagen!%b\n" "$RED" "$NC"
        printf "   Behebe die Fehler und führe die Module einzeln erneut aus:\n"
        printf "   ./install.sh --module=<name>\n"
    fi
}

# ==============================================================================
# Interactive Menu
# ==============================================================================

interactive_menu() {
    local modules
    mapfile -t modules < <(discover_modules)

    printf "\n%b%bEndeavourOS + Hyprland Dotfiles Installer%b\n" "$BOLD" "$CYAN" "$NC"
    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "$BLUE" "$NC"

    local options=("Vollinstallation (alle Module)")
    for mod in "${modules[@]}"; do
        local mod_file="${DOTFILES_DIR}/modules/${mod}.sh"
        local description
        description="$(module_get_meta "$mod_file" "Description")"
        options+=("${description:-$mod}")
    done
    options+=("Beenden")

    PS3=$'\nWähle eine Option (Nummer): '
    select _ in "${options[@]}"; do
        if [[ "$REPLY" == "1" ]]; then
            run_all_modules
            break
        elif [[ "$REPLY" == "$(( ${#options[@]} ))" ]]; then
            printf "Abgebrochen.\n"
            exit 0
        elif [[ "$REPLY" -ge 2 && "$REPLY" -le "$(( ${#options[@]} - 1 ))" ]]; then
            local idx=$(( REPLY - 2 ))
            run_module_safe "${modules[$idx]}"
            break
        else
            printf "Ungültige Auswahl: %s\n" "$REPLY"
        fi
    done
}

# ==============================================================================
# Argument Parsing
# ==============================================================================

show_help() {
    printf "Usage: %s [OPTIONS]\n\n" "$(basename "$0")"
    printf "Options:\n"
    printf "  --module=<name>        Run a specific module (by filename without .sh)\n"
    printf "  --skip=<name,name>     Skip specified modules (comma-separated)\n"
    printf "  --dry-run              Print commands without executing\n"
    printf "  --list                 List all available modules\n"
    printf "  --help                 Show this help\n\n"
    printf "Examples:\n"
    printf "  ./install.sh                              Interactive menu\n"
    printf "  ./install.sh --module=04-setup-shell      Run single module\n"
    printf "  ./install.sh --skip=setup-nvidia,setup-libvirt   Skip modules\n"
    printf "  ./install.sh --dry-run                    Simulate full install\n"
}

list_modules() {
    printf "Available modules:\n\n"
    local modules
    mapfile -t modules < <(discover_modules)
    for mod in "${modules[@]}"; do
        local mod_file="${DOTFILES_DIR}/modules/${mod}.sh"
        local description severity
        description="$(module_get_meta "$mod_file" "Description")"
        severity="$(module_get_meta "$mod_file" "Severity")"
        printf "  %-35s %b[%s]%b  %s\n" "$mod" "$BLUE" "${severity:-?}" "$NC" "${description:-}"
    done
}

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --module=*)
                SELECTED_MODULE="${arg#*=}"
                ;;
            --skip=*)
                SKIP_MODULES="${arg#*=}"
                ;;
            --dry-run)
                DRY_RUN="true"
                export DRY_RUN
                ;;
            --list)
                list_modules
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_err "Unknown argument: $arg"
                show_help
                exit 1
                ;;
        esac
    done
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

main() {
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    printf "=== Install log: %s ===\n" "$(date)" >> "$LOG_FILE"

    parse_args "$@"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Dry-run mode enabled. No changes will be made."
    fi

    check_not_root
    check_os

    if [[ -n "$SELECTED_MODULE" ]]; then
        # Allow both "04-setup-shell" and "setup-shell" formats
        local found=""
        for mod_file in "${DOTFILES_DIR}/modules/"*"${SELECTED_MODULE}"*.sh; do
            if [[ -f "$mod_file" ]]; then
                found="$(basename "$mod_file" .sh)"
                break
            fi
        done

        if [[ -n "$found" ]]; then
            run_module_safe "$found"
        else
            log_err "Module not found: $SELECTED_MODULE"
            log_info "Use --list to see available modules."
            exit 1
        fi
    else
        interactive_menu
    fi

    print_summary

    printf "\n%b%bInstallation abgeschlossen!%b\n" "$BOLD" "$GREEN" "$NC"
    printf "Log gespeichert in: %s\n" "$LOG_FILE"

    # Exit 1 if critical modules failed
    for mod in "${FAILED_MODULES[@]}"; do
        local mod_file="${DOTFILES_DIR}/modules/${mod}.sh"
        local severity
        severity="$(module_get_meta "$mod_file" "Severity")"
        if [[ "${severity:-}" == "kritisch" ]]; then
            exit 1
        fi
    done
}

main "$@"

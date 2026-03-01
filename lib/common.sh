#!/usr/bin/env bash
# lib/common.sh – Shared logging, command execution, and config linking functions

# Prevent double-sourcing
[[ -n "${_LIB_COMMON_LOADED:-}" ]] && return 0
readonly _LIB_COMMON_LOADED=1

# ==============================================================================
# Colors & Output
# ==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log_ok()    { printf "%b✓%b %s\n" "$GREEN"  "$NC" "$1" | tee -a "$LOG_FILE"; }
log_err()   { printf "%b✗%b %s\n" "$RED"    "$NC" "$1" | tee -a "$LOG_FILE"; }
log_warn()  { printf "%b⚡%b %s\n" "$YELLOW" "$NC" "$1" | tee -a "$LOG_FILE"; }
log_info()  { printf "%b→%b %s\n" "$BLUE"   "$NC" "$1" | tee -a "$LOG_FILE"; }
log_title() { printf "\n%b%b=== %s ===%b\n" "$BOLD" "$CYAN" "$1" "$NC" | tee -a "$LOG_FILE"; }

# ==============================================================================
# Command Execution
# ==============================================================================

# Dry-run wrapper: print command instead of executing
run_cmd() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        printf "%b[DRY-RUN]%b %s\n" "$YELLOW" "$NC" "$*"
    else
        "$@"
    fi
}

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Require a command to exist, exit with error if missing
require_cmd() {
    local cmd="$1"
    local hint="${2:-}"
    if ! cmd_exists "$cmd"; then
        log_err "Required command not found: $cmd"
        [[ -n "$hint" ]] && log_info "Hint: $hint"
        return 1
    fi
}

# Create directory with logging
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        run_cmd mkdir -p "$dir"
        log_ok "Created directory: $dir"
    fi
}

# ==============================================================================
# Config Linking
# ==============================================================================

# Create symlink with backup of existing non-symlink files/dirs
link_config() {
    local src="$1"
    local dst="$2"

    # Create parent directory if needed
    ensure_dir "$(dirname "$dst")"

    # Backup if target exists and is not already a symlink
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        ensure_dir "$BACKUP_DIR"
        log_warn "Backing up existing: $dst → $BACKUP_DIR/"
        run_cmd mv "$dst" "${BACKUP_DIR}/$(basename "$dst")"
    fi

    run_cmd ln -sfn "$src" "$dst"
    log_ok "Linked: $dst → $src"
}

# ==============================================================================
# Package List Reading
# ==============================================================================

# Read all .txt files from a directory, skip comments and empty lines
# Usage: read_packages packages/core.txt packages/desktop.txt
#    or: read_packages_dir packages/
read_packages_from_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -v '^\s*#' "$file" | grep -v '^\s*$' || true
    fi
}

read_packages_from_dir() {
    local dir="$1"
    local exclude_pattern="${2:-^$}"

    for f in "$dir"/*.txt; do
        [[ -f "$f" ]] || continue
        [[ "$(basename "$f")" =~ $exclude_pattern ]] && continue
        read_packages_from_file "$f"
    done | sort -u
}

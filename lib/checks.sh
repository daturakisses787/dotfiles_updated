#!/usr/bin/env bash
# lib/checks.sh – Pre-flight checks before installation

[[ -n "${_LIB_CHECKS_LOADED:-}" ]] && return 0
readonly _LIB_CHECKS_LOADED=1

# Abort if running as root
check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        log_err "Do not run as root. Use a regular user with sudo privileges."
        exit 1
    fi
}

# Verify we're on an Arch-based system
check_os() {
    if ! command -v pacman &>/dev/null; then
        log_err "pacman not found. This script requires an Arch-based system."
        exit 1
    fi

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        local os_id="${ID:-unknown}"
        local os_like="${ID_LIKE:-}"

        if [[ "$os_id" == "endeavouros" ]]; then
            log_ok "EndeavourOS detected."
        elif [[ "$os_like" == *"arch"* ]]; then
            log_warn "Not EndeavourOS but Arch-based (${os_id}). Proceeding anyway."
        else
            log_warn "Unknown distro: ${os_id}. Proceeding on best effort."
        fi
    fi
}

# Check internet connectivity
check_internet() {
    if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
        log_err "No internet connection. Cannot install packages."
        exit 1
    fi
    log_ok "Internet connection verified."
}

#!/usr/bin/env bash
# lib/idempotent.sh – Idempotency helpers for safe re-runs

[[ -n "${_LIB_IDEMPOTENT_LOADED:-}" ]] && return 0
readonly _LIB_IDEMPOTENT_LOADED=1

# Check if a pacman/AUR package is installed
pkg_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Check if a symlink already points to the correct target
link_is_correct() {
    local link_path="$1"
    local expected_target="$2"
    [[ -L "$link_path" ]] && [[ "$(readlink -f "$link_path")" == "$(readlink -f "$expected_target")" ]]
}

# Check if a systemd system service is enabled
service_enabled() {
    systemctl is-enabled "$1" &>/dev/null
}

# Check if a systemd user service is enabled
user_service_enabled() {
    systemctl --user is-enabled "$1" &>/dev/null
}

# Check if a file exists and its content matches another file
file_matches() {
    [[ -f "$1" ]] && [[ -f "$2" ]] && diff -q "$1" "$2" &>/dev/null
}

# Check if a line exists in a file
line_in_file() {
    local line="$1"
    local file="$2"
    [[ -f "$file" ]] && grep -qF "$line" "$file"
}

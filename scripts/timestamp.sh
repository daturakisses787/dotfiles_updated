#!/usr/bin/env bash
# timestamp.sh – Recording marker system with session tracking
# Usage: timestamp.sh marker | note | end
set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

STATE_FILE="${HOME}/.cache/timestamp-session"
TIMESTAMP_DIR="${HOME}/Documents/timestamps"

# ---------------------------------------------------------------------------
# Helper: format elapsed seconds as HH:MM:SS
# ---------------------------------------------------------------------------

format_elapsed() {
    local total_secs="$1"
    local h m s
    h=$(( total_secs / 3600 ))
    m=$(( (total_secs % 3600) / 60 ))
    s=$(( total_secs % 60 ))
    printf "%02d:%02d:%02d" "$h" "$m" "$s"
}

# ---------------------------------------------------------------------------
# Helper: count marker lines in current log (lines starting with "[")
# ---------------------------------------------------------------------------

count_markers() {
    local log_file="$1"
    local count
    count=$(grep -c "^\[" "${log_file}" 2>/dev/null) || count=0
    printf "%s" "${count}"
}

# ---------------------------------------------------------------------------
# Helper: send desktop notification
# ---------------------------------------------------------------------------

notify() {
    local summary="$1"
    local body="${2:-}"
    notify-send --app-name="Timestamp" --urgency=low "${summary}" "${body}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Command: marker
# Starts a session if none active, otherwise sets a simple marker
# ---------------------------------------------------------------------------

cmd_marker() {
    if [[ ! -f "${STATE_FILE}" ]]; then
        # Start new session
        mkdir -p "${TIMESTAMP_DIR}"

        local start_time timestamp_human log_name log_file
        start_time="$(date +%s)"
        timestamp_human="$(date '+%Y-%m-%d %H:%M:%S')"
        log_name="session_$(date '+%Y%m%d_%H%M%S').md"
        log_file="${TIMESTAMP_DIR}/${log_name}"

        # Persist session state: start_time|log_file
        printf "%s|%s\n" "${start_time}" "${log_file}" > "${STATE_FILE}"

        # Create log file
        {
            printf "# Session %s\n\n" "${timestamp_human}"
            printf "[00:00:00] Session gestartet\n"
        } > "${log_file}"

        notify "Session gestartet" "${timestamp_human}"
    else
        # Add simple marker to running session
        local start_time log_file
        IFS='|' read -r start_time log_file < "${STATE_FILE}"

        local now elapsed elapsed_fmt
        now="$(date +%s)"
        elapsed=$(( now - start_time ))
        elapsed_fmt="$(format_elapsed "${elapsed}")"

        printf "[%s] Marker\n" "${elapsed_fmt}" >> "${log_file}"

        notify "Marker gesetzt" "+${elapsed_fmt}"
    fi
}

# ---------------------------------------------------------------------------
# Command: note
# Adds a marker with a note (entered via wofi dmenu)
# ---------------------------------------------------------------------------

cmd_note() {
    if [[ ! -f "${STATE_FILE}" ]]; then
        notify "Keine aktive Session" "Starte eine Session mit SUPER+M"
        exit 0
    fi

    local start_time log_file
    IFS='|' read -r start_time log_file < "${STATE_FILE}"

    # Open wofi dmenu for note input
    local note
    note="$(printf "" | wofi --show dmenu --prompt "Notiz:" --lines 1 2>/dev/null)" || note=""

    # Only write if user entered something
    if [[ -z "${note}" ]]; then
        exit 0
    fi

    local now elapsed elapsed_fmt
    now="$(date +%s)"
    elapsed=$(( now - start_time ))
    elapsed_fmt="$(format_elapsed "${elapsed}")"

    printf "[%s] Notiz: %s\n" "${elapsed_fmt}" "${note}" >> "${log_file}"

    notify "Notiz gesetzt" "+${elapsed_fmt}: ${note}"
}

# ---------------------------------------------------------------------------
# Command: end
# Ends the current session and writes a summary
# ---------------------------------------------------------------------------

cmd_end() {
    if [[ ! -f "${STATE_FILE}" ]]; then
        notify "Keine aktive Session" "Starte eine Session mit SUPER+M"
        exit 0
    fi

    local start_time log_file
    IFS='|' read -r start_time log_file < "${STATE_FILE}"

    local now elapsed elapsed_fmt end_human
    now="$(date +%s)"
    elapsed=$(( now - start_time ))
    elapsed_fmt="$(format_elapsed "${elapsed}")"
    end_human="$(date '+%H:%M:%S')"

    # Count all timestamped lines, subtract 1 for the "Session gestartet" line
    local marker_count real_markers duration_min duration_sec
    marker_count="$(count_markers "${log_file}")"
    real_markers=$(( marker_count > 0 ? marker_count - 1 : 0 ))
    duration_min=$(( elapsed / 60 ))
    duration_sec=$(( elapsed % 60 ))

    {
        printf -- "---\n"
        printf "Session beendet: %s (Gesamtdauer: %d min %d sek, %d Marker gesetzt)\n" \
            "${end_human}" "${duration_min}" "${duration_sec}" "${real_markers}"
    } >> "${log_file}"

    rm -f "${STATE_FILE}"

    notify "Session beendet" "${elapsed_fmt} – ${real_markers} Marker  |  $(basename "${log_file}")"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

case "${1:-}" in
    marker) cmd_marker ;;
    note)   cmd_note   ;;
    end)    cmd_end    ;;
    *)
        printf "Usage: %s marker|note|end\n" "$(basename "$0")" >&2
        exit 1
        ;;
esac

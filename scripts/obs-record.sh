#!/usr/bin/env bash
# obs-record.sh – Toggle OBS recording with synchronized timestamp session
# Starts/stops OBS recording and a matching timestamp session together.
# Usage: obs-record.sh (no arguments – state is derived from timestamp session file)

set -euo pipefail

readonly STATE_FILE="${HOME}/.cache/timestamp-session"
readonly TIMESTAMP="${HOME}/.local/bin/timestamp.sh"
readonly OBS_WS_CONFIG="${HOME}/.config/obs-studio/plugin_config/obs-websocket/config.json"

# Build WebSocket URL from OBS plugin config (reads password at runtime)
build_ws_url() {
    if [[ -f "$OBS_WS_CONFIG" ]] && command -v jq &>/dev/null; then
        local port password
        port="$(jq -r '.server_port // 4455' "$OBS_WS_CONFIG")"
        password="$(jq -r '.server_password // ""' "$OBS_WS_CONFIG")"
        printf 'obsws://localhost:%s/%s' "$port" "$password"
    else
        printf 'obsws://localhost:4455/'
    fi
}

WS_URL="$(build_ws_url)"
readonly WS_URL

# Check OBS WebSocket connectivity before doing anything
if ! obs-cmd -w "$WS_URL" recording status &>/dev/null; then
    notify-send --urgency=normal --app-name="OBS" "OBS nicht erreichbar" \
        "OBS öffnen und WebSocket aktivieren: Werkzeuge → WebSocket Server-Einstellungen" 2>/dev/null || true
    exit 1
fi

if [[ -f "$STATE_FILE" ]]; then
    obs-cmd -w "$WS_URL" recording stop
    "$TIMESTAMP" end
else
    obs-cmd -w "$WS_URL" recording start
    "$TIMESTAMP" marker
fi

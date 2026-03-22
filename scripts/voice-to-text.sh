#!/usr/bin/env bash
# voice-to-text.sh – Toggle speech-to-text via whisper.cpp (CUDA)
# 1st call: start recording, 2nd call: stop, transcribe, paste text
# Usage: voice-to-text.sh (no arguments – state is derived from PID file)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration (overridable via environment)
# ---------------------------------------------------------------------------
readonly WHISPER_BIN="${WHISPER_BIN:-/usr/local/bin/whisper-cpp}"
readonly WHISPER_MODEL_DIR="${HOME}/.local/share/whisper-cpp"
readonly WHISPER_MODEL="${WHISPER_MODEL:-ggml-large-v3.bin}"
readonly WHISPER_LANG="${WHISPER_LANG:-auto}"
readonly VOICE_MIC="${VOICE_MIC:-default}"

readonly PID_FILE="${HOME}/.cache/voice-to-text.pid"
readonly WAV_FILE="${HOME}/.cache/voice-to-text.wav"
readonly VAULT_DIR="${HOME}/Obsidian/EdensGarden/05-Resources/Voice-Notes"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
notify() {
    notify-send --urgency=normal --app-name="Voice-to-Text" "$@" 2>/dev/null || true
}

cleanup() {
    rm -f "$PID_FILE" "$WAV_FILE"
}

die() {
    notify "Fehler" "$1"
    cleanup
    exit 1
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
for cmd in ffmpeg wl-copy wtype; do
    command -v "$cmd" &>/dev/null || die "$cmd nicht gefunden"
done
[[ -x "$WHISPER_BIN" ]] || die "whisper-cpp nicht gefunden: $WHISPER_BIN"
[[ -f "${WHISPER_MODEL_DIR}/${WHISPER_MODEL}" ]] || die "Whisper-Modell nicht gefunden: ${WHISPER_MODEL_DIR}/${WHISPER_MODEL}"

# ---------------------------------------------------------------------------
# Toggle logic
# ---------------------------------------------------------------------------
if [[ -f "$PID_FILE" ]]; then
    # ── STOP recording & transcribe ──────────────────────────────────────
    pid="$(cat "$PID_FILE")"

    # Stop ffmpeg gracefully (SIGINT → proper WAV header)
    if kill -0 "$pid" 2>/dev/null; then
        kill -INT "$pid"
        # Wait for ffmpeg to finish writing
        for _ in $(seq 1 30); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
    rm -f "$PID_FILE"

    [[ -f "$WAV_FILE" ]] || die "Keine Aufnahme gefunden"

    # Check minimum file size (empty recordings < 1KB)
    file_size="$(stat -c%s "$WAV_FILE" 2>/dev/null || echo 0)"
    if (( file_size < 1024 )); then
        notify "Aufnahme zu kurz" "Bitte länger sprechen"
        cleanup
        exit 0
    fi

    notify "Transkribiere..." "Whisper verarbeitet die Aufnahme"

    # Transcribe with whisper.cpp
    transcript="$("$WHISPER_BIN" \
        -m "${WHISPER_MODEL_DIR}/${WHISPER_MODEL}" \
        -l "$WHISPER_LANG" \
        -nt \
        --prompt "Gemischter Text auf Deutsch und Englisch mit Fachbegriffen." \
        -f "$WAV_FILE" 2>/dev/null)" || die "Transkription fehlgeschlagen"

    # Trim whitespace
    transcript="$(printf '%s' "$transcript" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if [[ -z "$transcript" ]]; then
        notify "Kein Text erkannt" "Aufnahme war möglicherweise zu leise"
        cleanup
        exit 0
    fi

    # Copy to clipboard
    printf '%s' "$transcript" | wl-copy

    # Try pasting via Ctrl+V (works in most Wayland apps)
    if wtype -M ctrl -k v 2>/dev/null; then
        notify "Text eingefügt" "${transcript:0:80}…"
    else
        # Fallback: save as Voice Note in Obsidian vault
        timestamp="$(date '+%Y-%m-%dT%H:%M:%S')"
        date_part="$(date '+%Y-%m-%d')"
        time_part="$(date '+%H-%M-%S')"
        note_file="${VAULT_DIR}/Voice-Note_${date_part}_${time_part}.md"

        mkdir -p "$VAULT_DIR"
        cat > "$note_file" <<VOICENOTE
---
created: ${timestamp}
type: voice-note
---
# Voice Note – ${date_part} $(date '+%H:%M')

${transcript}
VOICENOTE

        notify "Voice Note gespeichert" "Text im Clipboard, Note in Obsidian"
    fi

    rm -f "$WAV_FILE"
else
    # ── START recording ──────────────────────────────────────────────────
    # Record 16kHz mono WAV via PipeWire (pulse backend)
    ffmpeg -y \
        -f pulse \
        -i "$VOICE_MIC" \
        -ar 16000 \
        -ac 1 \
        -c:a pcm_s16le \
        "$WAV_FILE" \
        </dev/null &>/dev/null &

    echo $! > "$PID_FILE"
    notify "Aufnahme gestartet" "Erneut drücken zum Stoppen (SUPER+F3)"
fi

#!/usr/bin/env bash
# Description: Whisper-Modell für Voice-to-Text herunterladen
# Severity: optional
# Depends: 03-link-configs
# Fix: Lade ggml-large-v3.bin manuell nach ~/.local/share/whisper-cpp/
# Autorun: true

set -euo pipefail

module_run() {
    local model_dir="${XDG_DATA_HOME:-$HOME/.local/share}/whisper-cpp"
    local model_file="${model_dir}/ggml-large-v3.bin"
    local model_url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin"

    if [[ -f "$model_file" ]]; then
        log_ok "Whisper model already present: $model_file"
        return 0
    fi

    if ! command -v whisper-cpp &>/dev/null; then
        log_warn "whisper-cpp not installed – skipping model download"
        return 0
    fi

    log_info "Downloading Whisper large-v3 model (~3 GB) to $model_dir …"
    run_cmd mkdir -p "$model_dir"
    run_cmd curl -L --progress-bar -o "$model_file" "$model_url"
    log_ok "Whisper model downloaded: $model_file"
}

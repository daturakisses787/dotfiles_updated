#!/usr/bin/env bash
# Description: Claude Code Konfiguration einrichten
# Severity: optional
# Fix: Prüfe extras/claude/

set -euo pipefail

module_run() {
    local claude_src="${DOTFILES_DIR}/extras/claude"
    local claude_dst="${HOME}/.claude"

    if [[ ! -d "$claude_src" ]]; then
        log_warn "No claude config found at extras/claude/"
        return 0
    fi

    ensure_dir "$claude_dst"

    # Copy CLAUDE.md (global instructions)
    if [[ -f "${claude_src}/CLAUDE.md" ]]; then
        if [[ -f "${claude_dst}/CLAUDE.md" ]] && file_matches "${claude_src}/CLAUDE.md" "${claude_dst}/CLAUDE.md"; then
            log_ok "CLAUDE.md already up to date."
        else
            run_cmd cp "${claude_src}/CLAUDE.md" "${claude_dst}/CLAUDE.md"
            log_ok "CLAUDE.md copied to ~/.claude/"
        fi
    fi

    # Copy settings.json
    if [[ -f "${claude_src}/settings.json" ]]; then
        if [[ -f "${claude_dst}/settings.json" ]] && file_matches "${claude_src}/settings.json" "${claude_dst}/settings.json"; then
            log_ok "Claude settings.json already up to date."
        else
            run_cmd cp "${claude_src}/settings.json" "${claude_dst}/settings.json"
            log_ok "Claude settings.json copied to ~/.claude/"
        fi
    fi

    log_ok "Claude config setup complete."
}

#!/usr/bin/env bash
# Description: GitHub SSH-Key einrichten (manuell nach Installation)
# Severity: manual
# Autorun: false
# Depends: 02-install-packages
# Fix: Installiere openssh und konfiguriere SSH-Key manuell

set -euo pipefail

module_run() {
    require_cmd ssh-keygen "Install openssh"

    local ssh_dir="${HOME}/.ssh"
    local key_file="${ssh_dir}/id_ed25519"

    ensure_dir "$ssh_dir"
    run_cmd chmod 700 "$ssh_dir"

    if [[ -f "$key_file" ]]; then
        log_ok "SSH key already exists: $key_file"
    else
        log_info "Generating new SSH key..."
        run_cmd ssh-keygen -t ed25519 -C "${USER}@$(hostname)" -f "$key_file" -N ""
        log_ok "SSH key generated: $key_file"
    fi

    # Start ssh-agent if not running
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
        eval "$(ssh-agent -s)" > /dev/null
        log_info "Started ssh-agent."
    fi

    run_cmd ssh-add "$key_file" 2>/dev/null || true

    # Configure SSH for GitHub
    local ssh_config="${ssh_dir}/config"
    if [[ -f "$ssh_config" ]] && grep -q "Host github.com" "$ssh_config" 2>/dev/null; then
        log_ok "SSH config for GitHub already exists."
    else
        log_info "Adding GitHub SSH config..."
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            printf '%b[DRY-RUN]%b Append GitHub SSH config to %s\n' "$YELLOW" "$NC" "$ssh_config"
        else
            cat >> "$ssh_config" << 'SSHEOF'

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
SSHEOF
        fi
        run_cmd chmod 600 "$ssh_config"
        log_ok "SSH config for GitHub added."
    fi

    # Display public key for user to add to GitHub
    if [[ -f "${key_file}.pub" ]]; then
        log_info "Public key (add to https://github.com/settings/keys):"
        cat "${key_file}.pub"
    fi

    log_ok "GitHub SSH setup complete."
}

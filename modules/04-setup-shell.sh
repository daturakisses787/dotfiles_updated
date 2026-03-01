#!/usr/bin/env bash
# Description: ZSH + Oh-My-Zsh + Powerlevel10k einrichten
# Severity: wichtig
# Depends: 02-install-packages
# Fix: Stelle sicher, dass zsh installiert ist

set -euo pipefail

module_run() {
    require_cmd zsh "Install zsh first"

    # Set ZSH as default shell
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current_shell" != "$(command -v zsh)" ]]; then
        log_info "Setting ZSH as default shell..."
        run_cmd sudo chsh -s "$(command -v zsh)" "$USER"
        log_ok "Default shell changed to ZSH."
    else
        log_ok "ZSH is already the default shell."
    fi

    # Install Oh-My-Zsh
    local omz_dir="${HOME}/.oh-my-zsh"
    if [[ -d "$omz_dir" ]]; then
        log_ok "Oh-My-Zsh already installed."
    else
        log_info "Installing Oh-My-Zsh..."
        # shellcheck disable=SC2016
        run_cmd sh -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
        log_ok "Oh-My-Zsh installed."
    fi

    # Link ZSH config files
    local zsh_src="${DOTFILES_DIR}/config/zsh"

    # Link .zshrc to home
    if [[ -f "${zsh_src}/.zshrc" ]]; then
        if link_is_correct "${HOME}/.zshrc" "${zsh_src}/.zshrc"; then
            log_ok "Already linked: .zshrc"
        else
            link_config "${zsh_src}/.zshrc" "${HOME}/.zshrc"
        fi
    fi

    # Link .p10k.zsh to home
    if [[ -f "${zsh_src}/.p10k.zsh" ]]; then
        if link_is_correct "${HOME}/.p10k.zsh" "${zsh_src}/.p10k.zsh"; then
            log_ok "Already linked: .p10k.zsh"
        else
            link_config "${zsh_src}/.p10k.zsh" "${HOME}/.p10k.zsh"
        fi
    fi

    # Link aliases.zsh to zsh config dir
    local zsh_config_dir="${CONFIG_DIR}/zsh"
    ensure_dir "$zsh_config_dir"
    if [[ -f "${zsh_src}/aliases.zsh" ]]; then
        if link_is_correct "${zsh_config_dir}/aliases.zsh" "${zsh_src}/aliases.zsh"; then
            log_ok "Already linked: aliases.zsh"
        else
            link_config "${zsh_src}/aliases.zsh" "${zsh_config_dir}/aliases.zsh"
        fi
    fi

    log_ok "Shell setup complete."
}

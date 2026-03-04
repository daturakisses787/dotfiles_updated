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

    # Link system-installed powerlevel10k to OMZ custom themes
    local p10k_system="/usr/share/zsh-theme-powerlevel10k"
    local p10k_omz="${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
    if [[ -d "$p10k_system" ]]; then
        ensure_dir "${HOME}/.oh-my-zsh/custom/themes"
        if link_is_correct "$p10k_omz" "$p10k_system"; then
            log_ok "Already linked: powerlevel10k → OMZ themes"
        else
            link_config "$p10k_system" "$p10k_omz"
        fi
    fi

    # Link ZSH config files
    local zsh_src="${DOTFILES_DIR}/config/zsh"

    # Link .zshenv to home (sets ZDOTDIR)
    if [[ -f "${zsh_src}/.zshenv" ]]; then
        if link_is_correct "${HOME}/.zshenv" "${zsh_src}/.zshenv"; then
            log_ok "Already linked: .zshenv"
        else
            link_config "${zsh_src}/.zshenv" "${HOME}/.zshenv"
        fi
    fi

    # Link .zshrc to ZDOTDIR (~/.config/zsh/) so ZSH finds it
    local zsh_config_dir="${CONFIG_DIR}/zsh"
    ensure_dir "$zsh_config_dir"
    if [[ -f "${zsh_src}/.zshrc" ]]; then
        if link_is_correct "${zsh_config_dir}/.zshrc" "${zsh_src}/.zshrc"; then
            log_ok "Already linked: .zshrc → ZDOTDIR"
        else
            link_config "${zsh_src}/.zshrc" "${zsh_config_dir}/.zshrc"
        fi
        # Clean up stale symlink in $HOME (from previous installs)
        if [[ -L "${HOME}/.zshrc" ]]; then
            rm -f "${HOME}/.zshrc"
            log_info "Removed stale symlink: ~/.zshrc"
        fi
    fi

    # Link .p10k.zsh to ZDOTDIR (~/.config/zsh/)
    if [[ -f "${zsh_src}/.p10k.zsh" ]]; then
        if link_is_correct "${zsh_config_dir}/.p10k.zsh" "${zsh_src}/.p10k.zsh"; then
            log_ok "Already linked: .p10k.zsh → ZDOTDIR"
        else
            link_config "${zsh_src}/.p10k.zsh" "${zsh_config_dir}/.p10k.zsh"
        fi
        # Clean up stale symlink in $HOME
        if [[ -L "${HOME}/.p10k.zsh" ]]; then
            rm -f "${HOME}/.p10k.zsh"
            log_info "Removed stale symlink: ~/.p10k.zsh"
        fi
    fi

    # Link aliases.zsh to zsh config dir
    if [[ -f "${zsh_src}/aliases.zsh" ]]; then
        if link_is_correct "${zsh_config_dir}/aliases.zsh" "${zsh_src}/aliases.zsh"; then
            log_ok "Already linked: aliases.zsh"
        else
            link_config "${zsh_src}/aliases.zsh" "${zsh_config_dir}/aliases.zsh"
        fi
    fi

    log_ok "Shell setup complete."
}

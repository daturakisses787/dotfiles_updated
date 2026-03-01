# aliases.zsh – Shell Aliases
# Sourced by .zshrc

# ==============================================================================
# System Package Management
# ==============================================================================
alias update='sudo pacman -Syu && yay -Sua --noconfirm'
alias install='yay -S'
alias remove='sudo pacman -Rns'
alias search='yay -Ss'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq 2>/dev/null) 2>/dev/null || echo "Nothing to remove"'
alias pkglist='pacman -Qqe'                     # List explicitly installed packages
alias pkgsize='expac -H M "%m\t%n" | sort -h'  # Packages sorted by size

# ==============================================================================
# Navigation
# ==============================================================================
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# ==============================================================================
# File Listing (eza if available, fallback to ls)
# ==============================================================================
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -alF --icons --group-directories-first --git'
    alias la='eza -A --icons --group-directories-first'
    alias lt='eza -T --icons --group-directories-first'  # tree
    alias l='eza -lF --icons --group-directories-first'
else
    alias ls='ls --color=auto'
    alias ll='ls -alFh --color=auto'
    alias la='ls -A --color=auto'
fi

# ==============================================================================
# File Operations
# ==============================================================================
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'
alias mkdir='mkdir -pv'

# bat as cat replacement
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
    alias catn='bat'  # with line numbers and style
fi

# ripgrep as grep replacement
if command -v rg &>/dev/null; then
    alias grep='rg'
fi

# ==============================================================================
# Dotfiles Management
# ==============================================================================
alias dots='cd ~/dotfiles'
alias dots-edit='code ~/dotfiles'
alias dots-install='~/dotfiles/install.sh'
alias reload='source "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc" && echo "Shell reloaded."'

# ==============================================================================
# Hyprland
# ==============================================================================
alias hypr-reload='hyprctl reload && echo "Hyprland reloaded."'
alias hypr-log='journalctl --user -u hyprland -f'
alias hypr-monitors='hyprctl monitors'
alias hypr-workspaces='hyprctl workspaces'
alias hypr-clients='hyprctl clients'

# ==============================================================================
# Applications
# ==============================================================================
alias e='code'
alias f='thunar'
alias t='kitty'
alias fetch='fastfetch'

# ==============================================================================
# Git (extends oh-my-zsh git plugin)
# ==============================================================================
alias glog='git log --oneline --graph --decorate --all'
alias glogv='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset"'
alias gundo='git reset --soft HEAD~1'
alias gstash='git stash'
alias gpop='git stash pop'

# ==============================================================================
# System Info & Monitoring
# ==============================================================================
alias cpu='btop'
alias mem='free -h'
alias disk='df -h'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'

# ==============================================================================
# Clipboard (Wayland)
# ==============================================================================
alias xclip='wl-copy'
alias xpaste='wl-paste'

# ==============================================================================
# Wallpaper
# ==============================================================================
alias wallpaper='~/.config/scripts/wallpaper.sh &'
alias theme-dark='~/.config/scripts/theme-toggle.sh dark'
alias theme-light='~/.config/scripts/theme-toggle.sh light'

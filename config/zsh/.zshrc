# .zshrc – Main zsh Configuration
# Loaded when ZDOTDIR is set to ~/.config/zsh via ~/.zshenv

# ==============================================================================
# Fastfetch (must run before p10k instant prompt to preserve colors)
# ==============================================================================
fastfetch

# ==============================================================================
# Powerlevel10k Instant Prompt (must be near top)
# ==============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==============================================================================
# Oh-My-Zsh
# ==============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    sudo
    z
    colored-man-pages
    command-not-found
)

source "$ZSH/oh-my-zsh.sh"

# Load system-installed plugins (managed by pacman)
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ==============================================================================
# Environment Variables
# ==============================================================================
export EDITOR="code --wait"
export VISUAL="code --wait"
export BROWSER="chromium"
export TERMINAL="kitty"
export PAGER="less"

# XDG Base Directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# ==============================================================================
# Wayland Environment
# ==============================================================================
export MOZ_ENABLE_WAYLAND=1
export GDK_BACKEND="wayland,x11"
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_AUTO_SCREEN_SCALE_FACTOR=1
export _JAVA_AWT_WM_NONREPARENTING=1
export ELECTRON_OZONE_PLATFORM_HINT=auto

# ==============================================================================
# Path
# ==============================================================================
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/dotfiles/scripts:$PATH"

# ==============================================================================
# History
# ==============================================================================
HISTSIZE=50000
SAVEHIST=50000
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# ==============================================================================
# Completion
# ==============================================================================
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:descriptions' format '%B%d%b'

# ==============================================================================
# Aliases
# ==============================================================================
[[ -f "${ZDOTDIR:-$HOME/.config/zsh}/aliases.zsh" ]] && \
    source "${ZDOTDIR:-$HOME/.config/zsh}/aliases.zsh"

# ==============================================================================
# Powerlevel10k Config
# ==============================================================================
[[ -f "${ZDOTDIR:-$HOME/.config/zsh}/.p10k.zsh" ]] && \
    source "${ZDOTDIR:-$HOME/.config/zsh}/.p10k.zsh"

# Fallback: run p10k configure if no config exists
# [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh


#!/usr/bin/env bash
# nvidia-setup.sh – One-shot NVIDIA Wayland setup for EndeavourOS
# Run this script once after cloning dotfiles if you have an NVIDIA GPU.
# Requires sudo. Reboot after completion.

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

ok()   { printf "%b✓%b %s\n" "$GREEN"  "$NC" "$1"; }
info() { printf "%b→%b %s\n" "$BLUE"   "$NC" "$1"; }
warn() { printf "%b⚡%b %s\n" "$YELLOW" "$NC" "$1"; }

# ──────────────────────────────────────────────
# 1. Install nvidia-open kernel module
# ──────────────────────────────────────────────
info "Installing nvidia-open kernel module..."
sudo pacman -S --needed --noconfirm nvidia-open nvidia-utils lib32-nvidia-utils
ok "nvidia-open installed."

# ──────────────────────────────────────────────
# 2. GRUB: add nvidia-drm.modeset=1
# ──────────────────────────────────────────────
GRUB_DEFAULT="/etc/default/grub"
if grep -q "nvidia-drm.modeset=1" "$GRUB_DEFAULT" 2>/dev/null; then
    ok "nvidia-drm.modeset=1 already in GRUB."
else
    info "Adding nvidia-drm.modeset=1 to GRUB..."
    sudo sed -i \
        's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' \
        "$GRUB_DEFAULT"
    info "Regenerating grub.cfg..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ok "GRUB updated."
fi

# ──────────────────────────────────────────────
# 3. dracut: include nvidia modules in initramfs
# ──────────────────────────────────────────────
DRACUT_NVIDIA="/etc/dracut.conf.d/nvidia.conf"
if [[ -f "$DRACUT_NVIDIA" ]]; then
    ok "dracut nvidia config already exists."
else
    info "Creating $DRACUT_NVIDIA..."
    sudo tee "$DRACUT_NVIDIA" > /dev/null << 'EOF'
# Force-include nvidia kernel modules in initramfs
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
    info "Rebuilding initramfs..."
    sudo dracut --force
    ok "Initramfs rebuilt."
fi

# ──────────────────────────────────────────────
printf "\n%b✓ NVIDIA setup complete. Please reboot now.%b\n" "$GREEN" "$NC"

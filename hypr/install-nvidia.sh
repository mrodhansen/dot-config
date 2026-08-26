#!/usr/bin/env bash
# NVIDIA install on top of the generic Hyprland setup.
# Runs install.sh first, then layers on NVIDIA-specific packages and tweaks
# matching the env vars in hyprland.conf.
# Run as your normal user (not root). Sudo will be requested when needed.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as a regular user, not root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# --- Run the generic installer first ------------------------------------------
if [[ -x "$SCRIPT_DIR/install.sh" ]]; then
    echo ":: Running generic install.sh"
    "$SCRIPT_DIR/install.sh"
else
    echo "install.sh not found next to this script - aborting." >&2
    exit 1
fi

# --- NVIDIA packages ----------------------------------------------------------
NVIDIA_PKGS=(
    nvidia-dkms
    nvidia-utils
    libva-nvidia-driver
    egl-wayland
    linux-headers
)

echo ":: Installing NVIDIA packages"
sudo pacman -S --needed --noconfirm "${NVIDIA_PKGS[@]}"

# --- Early KMS in mkinitcpio --------------------------------------------------
# Needed for proper Wayland + NVIDIA behaviour.
MKINIT=/etc/mkinitcpio.conf
if [[ -f "$MKINIT" ]] && ! grep -Eq '^MODULES=.*nvidia' "$MKINIT"; then
    echo ":: Adding nvidia modules to $MKINIT"
    sudo sed -i -E 's/^(MODULES=\()([^)]*)\)/\1\2 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINIT"
    sudo sed -i -E 's/  +/ /g; s/\( /(/' "$MKINIT"
    sudo mkinitcpio -P
fi

# --- nvidia-drm modeset kernel param -----------------------------------------
# Sets nvidia_drm.modeset=1 via a modprobe.d drop-in (works regardless of bootloader).
MODPROBE_FILE=/etc/modprobe.d/nvidia.conf
if [[ ! -f "$MODPROBE_FILE" ]] || ! grep -q 'nvidia_drm modeset=1' "$MODPROBE_FILE"; then
    echo ":: Writing $MODPROBE_FILE"
    echo 'options nvidia_drm modeset=1 fbdev=1' | sudo tee "$MODPROBE_FILE" >/dev/null
fi

cat <<'EOF'

Done (NVIDIA install).

Reboot before launching Hyprland so the DKMS module is in the running kernel
and nvidia_drm.modeset=1 takes effect.
EOF

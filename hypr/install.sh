#!/usr/bin/env bash
# Install everything required by this Hyprland config on Arch Linux.
# Generic version - no GPU-vendor packages. For NVIDIA, run install-nvidia.sh.
# Run as your normal user (not root). Sudo will be requested when needed.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as a regular user, not root." >&2
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    echo "pacman not found - this script targets Arch Linux." >&2
    exit 1
fi

echo ":: Syncing package databases"
sudo pacman -Sy --noconfirm

# --- Official repo packages ---------------------------------------------------
PACMAN_PKGS=(
    # Hyprland core + ecosystem
    hyprland
    hyprpaper
    hypridle
    hyprlock
    hyprshot
    xdg-desktop-portal-hyprland
    qt5-wayland
    qt6-wayland

    # Bar / notifications / launcher / file manager
    waybar
    swaync
    wofi
    thunar

    # Audio / brightness / media keys
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
    pavucontrol
    brightnessctl
    playerctl

    # Apps referenced by keybinds
    firefox

    # Misc utilities used by config / scripts
    polkit-gnome
    xdg-user-dirs
    git
    base-devel
)

echo ":: Installing official packages"
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# --- AUR helper ---------------------------------------------------------------
if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
    echo ":: No AUR helper found - bootstrapping paru"
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$tmpdir/paru-bin"
    (cd "$tmpdir/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
fi

if command -v paru &>/dev/null; then
    AUR_HELPER=paru
else
    AUR_HELPER=yay
fi

# --- AUR packages -------------------------------------------------------------
AUR_PKGS=(
    pyprland          # pypr (scratchpads / dropdowns referenced in binds)
    spotify           # bound to SUPER+X
    claude-desktop    # used by claude-first-launch.sh + window rules
)

echo ":: Installing AUR packages with $AUR_HELPER"
"$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"

# --- Hyprland plugin: dynamic-cursors -----------------------------------------
# hyprland.conf does: hyprctl plugin load .../dynamic-cursors.so
echo ":: Setting up hyprpm and dynamic-cursors plugin"
hyprpm update || true
if ! hyprpm list 2>/dev/null | grep -q dynamic-cursors; then
    hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors
fi
hyprpm enable dynamic-cursors || true
hyprpm reload || true

# --- Wallpaper / screenshot dirs ---------------------------------------------
mkdir -p "$HOME/Pictures" "$HOME/Screenshots"
if [[ ! -f "$HOME/Pictures/arch-linux_upscaled.png" ]]; then
    echo ":: NOTE: $HOME/Pictures/arch-linux_upscaled.png is missing - hyprpaper will fail until you add it."
fi

# --- Services -----------------------------------------------------------------
systemctl --user enable --now pipewire pipewire-pulse wireplumber || true

cat <<'EOF'

Done (generic install).

If this machine has an NVIDIA GPU, also run:
    ./install-nvidia.sh

Next steps:
  * Drop your wallpaper at ~/Pictures/arch-linux_upscaled.png (or edit hyprpaper.conf).
  * Make sure ~/.config/theme/colors-hyprland.conf exists (sourced by hyprland.conf).
  * Log in via a Wayland session and start Hyprland.
EOF

# Hyprland Config

My personal Hyprland setup for Arch Linux. Drops into `~/.config/hypr/` and ships
two install scripts so you can bootstrap a fresh machine in one command.

## What's in here

| File | Purpose |
| --- | --- |
| `hyprland.conf` | Main Hyprland config: monitors, keybinds, window rules, plugins |
| `hyprpaper.conf` | Wallpaper config (per-monitor) |
| `claude-first-launch.sh` | Helper that opens claude-desktop on the `magic` special workspace |
| `install.sh` | Generic Arch installer (no GPU vendor packages) |
| `install-nvidia.sh` | Runs `install.sh` then layers on the NVIDIA stack |

## Install

Clone into `~/.config/hypr` (back up anything that's already there):

```sh
git clone https://github.com/mrodhansen/hyprland.git ~/.config/hypr
cd ~/.config/hypr
```

Then pick one:

**Generic / non-NVIDIA**

```sh
./install.sh
```

**NVIDIA**

```sh
./install-nvidia.sh
```

Run as your normal user — the scripts call `sudo` when they need to. Don't
run them as root.

### What the scripts do

- Sync pacman, install Hyprland + ecosystem (hyprpaper, hypridle, hyprlock,
  hyprshot, waybar, swaync, wofi, thunar, xdg-desktop-portal-hyprland, qt
  wayland), audio (pipewire + wireplumber), media keys (brightnessctl,
  playerctl), firefox, polkit-gnome, base-devel + git.
- Bootstrap `paru` if no AUR helper is installed, then install AUR packages:
  `pyprland`, `spotify`, `claude-desktop`.
- Add the `dynamic-cursors` Hyprland plugin via `hyprpm` (referenced by
  `hyprland.conf`).
- Enable user services: `pipewire`, `pipewire-pulse`, `wireplumber`.
- Create `~/Pictures` and `~/Screenshots`.

`install-nvidia.sh` additionally:

- Installs `nvidia-dkms`, `nvidia-utils`, `libva-nvidia-driver`, `egl-wayland`,
  `linux-headers`.
- Adds `nvidia nvidia_modeset nvidia_uvm nvidia_drm` to `MODULES` in
  `/etc/mkinitcpio.conf` and rebuilds the initramfs.
- Drops `/etc/modprobe.d/nvidia.conf` with `options nvidia_drm modeset=1 fbdev=1`.

## After install

1. **Reboot** (especially on NVIDIA — DKMS module needs to be in the running
   kernel and `nvidia_drm.modeset=1` takes effect at boot).
2. Put a wallpaper at `~/Pictures/arch-linux_upscaled.png` or edit
   `hyprpaper.conf` to point somewhere else.
3. Make sure `~/.config/theme/colors-hyprland.conf` exists — `hyprland.conf`
   sources it on the first line for border colors.
4. Log into a Wayland session and launch Hyprland.

## Keybinds (cheat sheet)

`SUPER` is the mod key.

| Bind | Action |
| --- | --- |
| `SUPER + C` | Terminal |
| `SUPER + E` | File manager (thunar) |
| `SUPER + B` | Firefox |
| `SUPER + X` | Spotify |
| `SUPER + space` | wofi launcher |
| `SUPER + Q` | Kill active window |
| `SUPER + F` | Fullscreen |
| `SUPER + V` | Float + center current window |
| `SUPER + S` | Toggle `magic` special workspace |
| `SUPER + N` | pypr toggle term |
| `SUPER + T` | pypr toggle taskbar |
| `SUPER + 1..0` | Switch workspace |
| `SUPER + SHIFT + 1..0` | Move window to workspace |
| `SUPER + SHIFT + M` | Exit Hyprland |
| `Print` / `CTRL+Print` / `ALT+Print` | Window / region / active screenshot |

Volume, brightness, and media keys are wired to `wpctl`, `brightnessctl`, and
`playerctl`.

## Notes

- Terminal is set to `wezterm` in `hyprland.conf` but it isn't installed by the
  scripts — install your terminal of choice and update the `$terminal` line.
- Monitors are hardcoded for my layout (`eDP-1`, `HDMI-A-1`, `HDMI-A-2`). Edit
  the `monitor=` lines for your setup.

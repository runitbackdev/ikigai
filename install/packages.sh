#!/usr/bin/env bash
set -euo pipefail

PACMAN=(
  base-devel git rust rust-src quickshell qt6-shadertools cmake ninja
  cosmic-comp-ikigai cosmic-bg cosmic-settings cosmic-settings-daemon cosmic-idle cosmic-randr
  cosmic-icon-theme cosmic-sound-theme cosmic-files xdg-desktop-portal-cosmic greetd xorg-xwayland
  ghostty zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship
  zed neovim lazygit github-cli just discord
  docker docker-compose lazydocker mise
  zellij yazi btop
  grim slurp satty gpu-screen-recorder mpv brightnessctl upower power-profiles-daemon
  ripgrep fd fzf bat eza dust git-delta tealdeer jq wl-clipboard ufw fastfetch zip unzip openssh python-gobject
  bluez bluez-utils
  gnome-keyring libsecret gcr-4
  pacman-contrib kernel-modules-hook zram-generator plocate wireless-regdb scx-scheds scx-tools
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji adw-gtk-theme librsvg xorg-xcursorgen
  pipewire pipewire-pulse wireplumber
  xdg-user-dirs
)
AUR=(zen-browser-bin vicinae-bin pear-desktop-bin cosmic-viewer-git ttf-phosphor-icons ufw-docker)

case "$(cat "$IKIGAI_STATE/gpu")" in
  # Pinned to the 580xx LTS branch (AUR, proprietary modules): the 610.x open modules crash
  # Deadlock and other Proton games with Xid 109 CTX SWITCH TIMEOUT (Arch bbs 313841). The
  # nvidia-580xx-utils pkgbase builds the utils and dkms packages together. Back to
  # nvidia-open-dkms nvidia-utils (and lib32-nvidia-utils in ikigai-steam) once a release fixes it;
  # a box that already has 610 installed swaps with `paru -S --batchinstall`, since the old lib32
  # package pins nvidia-utils to its exact version and this loop installs one pkgbase at a time.
  nvidia) PACMAN+=(linux-headers); AUR+=(nvidia-580xx-utils lib32-nvidia-580xx-utils) ;;
  amd)    PACMAN+=(mesa vulkan-radeon) ;;
  intel)  PACMAN+=(mesa vulkan-intel) ;;
esac

[ "$(systemd-detect-virt)" = microsoft ] && PACMAN+=(hyperv)

# 32-bit packages (Steam and its drivers) come from multilib; enable it once, up front.
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

# Ikigai's own packages (packages/*/PKGBUILD): CI builds them into a pacman repository on
# the `packages` GitHub release. Unsigned so far, hence TrustAll.
if ! grep -q '^\[ikigai\]' /etc/pacman.conf; then
  printf '\n[ikigai]\nSigLevel = Optional TrustAll\nServer = https://github.com/runitbackdev/ikigai/releases/download/packages\n' | sudo tee -a /etc/pacman.conf >/dev/null
fi
# The forked compositor conflicts with Arch's, and --noconfirm answers no to the swap, so
# the stock package goes first. Its files go; the running compositor does not.
[ "$(pacman -Qq cosmic-comp 2>/dev/null)" = cosmic-comp ] && sudo pacman -Rdd --noconfirm cosmic-comp

sudo pacman -Syu --needed --noconfirm "${PACMAN[@]}"

# Until 2026-09-14 Ikigai rebuilt Qt's Wayland client around the layer-shell bug the forked
# compositor fixes. A box still carrying that rebuild goes back to stock: the pacman hook and
# its state go, and reinstalling qt6-base puts Arch's library back.
if [ -e /etc/pacman.d/hooks/ikigai-qt-wayland.hook ] || [ -e /var/lib/ikigai/qt-wayland ]; then
  sudo rm -rf /etc/pacman.d/hooks/ikigai-qt-wayland.hook /usr/local/lib/ikigai/ikigai-qt-wayland \
    /usr/local/share/ikigai/qt6-base /var/lib/ikigai/qt-wayland /var/cache/ikigai/qt
  sudo pacman -S --noconfirm qt6-base
  echo "stock Qt Wayland client restored; log out so the shell runs on the forked compositor"
fi

# Build on disk, not /tmp: tmpfs is RAM-limited and a Rust build needs GBs.
BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/ikigai/build"
mkdir -p "$BUILD_ROOT"

aur() {
  local build; build="$(mktemp -d -p "$BUILD_ROOT")"
  git clone -q "https://aur.archlinux.org/$1.git" "$build/$1"
  (cd "$build/$1" && makepkg -si --noconfirm --needed)
  rm -rf "$build"
}

paru --version >/dev/null 2>&1 || aur paru
for pkg in "${AUR[@]}"; do pacman -Q "$pkg" >/dev/null 2>&1 || aur "$pkg"; done

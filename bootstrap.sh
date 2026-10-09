#!/usr/bin/env bash
set -euo pipefail

# --- 1. detect package manager and install tools ---
if   command -v apt    >/dev/null; then
  sudo apt update
  sudo apt install -y git stow tmux neovim ripgrep fd-find build-essential curl unzip python3-dev
elif command -v pacman >/dev/null; then
  sudo pacman -Syu --needed --noconfirm git stow tmux neovim ripgrep fd base-devel curl unzip python openssh nodejs npm tree-sitter-cli pciutils
elif command -v dnf    >/dev/null; then
  sudo dnf install -y git stow tmux neovim ripgrep fd-find @development-tools curl unzip python3-devel
else
  echo "Unsupported distro"; exit 1
fi

# --- 2. python tooling: uv manages interpreters and venvs ---
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. mount /data by label (skips if the installer already added it)
if ! grep -qE '[[:space:]]/data[[:space:]]' /etc/fstab; then
  sudo mkdir -p /data
  echo 'LABEL=data /data ext4 defaults,noatime,nofail 0 2' | sudo tee -a /etc/fstab
  sudo systemctl daemon-reload && sudo mount -a
fi

# 4. link personal folders into home
for d in Documents Downloads Pictures Music Videos Desktop Games dev Projects; do
  [ -d "/data/$d" ] || continue
  [ -L "$HOME/$d" ] && continue
  if [ -e "$HOME/$d" ]; then
    rmdir "$HOME/$d" 2>/dev/null || { echo "SKIP $HOME/$d (not empty)"; continue; }
  fi
  ln -s "/data/$d" "$HOME/$d"
done

# --- 4b. desktop (Arch Only: run with --desktop ---
if [ "${1:-}" = "--desktop" ]; then
  if command -v pacman >/dev/null; then
    gpu_info=$(lspci | grep -E 'VGA|3D|DISPLAY' || true)
    gpu_pkgs=""
    if grep -qi 'AMD/ATI' <<<"$gpu_info"; then gpu_pkgs="vulkan-radeon"
    elif grep -qi 'Intel' <<<"$gpu_info"; then gpu_pkgs="vulkan-intel"
    else echo "NOTE: no AMD/Intel GPU detected; install gpu drivers manually"
    fi
    sudo pacman -S --needed --noconfirm hyprland ghostty wofi waybar $gpu_pkgs ttf-dejavu ttf-jetbrains-mono-nerd
  else
    echo "NOTE: --desktop is only set up for Arch; skipping"
  fi
fi

# --- 5. dotfiles ---
cd "$HOME/dotfiles"
stow --restow --no-folding -t "$HOME" tmux hypr ghostty

echo "Done. Restart your shell."

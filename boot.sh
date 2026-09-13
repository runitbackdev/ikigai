#!/usr/bin/env bash
# curl -fsSL https://raw.githubusercontent.com/runitbackdev/ikigai/main/boot.sh | bash
set -euo pipefail

IKIGAI_REPO="${IKIGAI_REPO:-https://github.com/runitbackdev/ikigai.git}"
IKIGAI_REF="${IKIGAI_REF:-main}"
IKIGAI_PATH="${IKIGAI_PATH:-$HOME/.local/share/ikigai}"

echo "==> Ikigai bootstrap"
sudo pacman -Syu --needed --noconfirm git

if [ -d "$IKIGAI_PATH/.git" ]; then
  git -C "$IKIGAI_PATH" fetch -q origin "$IKIGAI_REF"
  git -C "$IKIGAI_PATH" checkout -q "$IKIGAI_REF"
  git -C "$IKIGAI_PATH" pull -q --ff-only
else
  git clone -q --branch "$IKIGAI_REF" "$IKIGAI_REPO" "$IKIGAI_PATH"
fi

exec bash "$IKIGAI_PATH/install.sh"

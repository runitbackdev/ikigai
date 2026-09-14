#!/usr/bin/env bash
# Vendor the SVG sources of Bibata Modern (GPL-3) into cursors/bibata: the cursor shapes
# with their three placeholder colours (#00FF00 base, #0000FF outline, #FF0000 watch)
# untouched, and upstream's hotspot table. scripts/theme-build.py recolours them from a
# palette into themes/<name>/cursors/Ikigai; the theme package rasterises those at build.
set -euo pipefail
REV=v2.0.7
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/cursors/bibata"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL "https://github.com/ful1e5/Bibata_Cursor/archive/refs/tags/$REV.tar.gz" | tar -xzf - -C "$WORK" --strip-components=1
rm -rf "$DEST"
mkdir -p "$DEST"
# svg/modern is symlinks into svg/groups; copy what they point at.
cp -rL "$WORK/svg/modern" "$DEST/svg"
cp "$WORK/configs/normal/x.build.toml" "$DEST/hotspots.toml"
cp "$WORK/LICENSE" "$DEST/LICENSE"
echo "vendored cursors/bibata ($(find "$DEST/svg" -name '*.svg' | wc -l) SVGs) @ $REV"

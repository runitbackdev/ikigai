#!/usr/bin/env bash
# Runs inside an archlinux container in CI: syntax-check every script and
# verify every curated package name resolves in the official repos.
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(id -u)" -eq 0 ] && pacman -Sy --noconfirm >/dev/null
[ "$(id -u)" -eq 0 ] && pacman -S --noconfirm --needed python >/dev/null
for f in boot.sh install.sh install/*.sh bin/* scripts/*.sh packages/qt6-base/ikigai-qt-wayland; do
  case "$(head -1 "$f")" in
    *python*) python -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$f" ;;
    *) bash -n "$f" ;;
  esac
done
echo "syntax ok"

eval "$(sed -n '/^PACMAN=(/,/^)/p' install/packages.sh)"
official=(); ours=()
for p in "${PACMAN[@]}"; do case "$p" in *-ikigai) ours+=("$p") ;; *) official+=("$p") ;; esac; done
pacman -Sp --noconfirm "${official[@]}" >/dev/null
echo "all ${#official[@]} repo packages resolve"
# Ikigai's own packages come from packages/<name>/PKGBUILD (built by packages.yml).
for p in "${ours[@]}"; do
  f="packages/${p%-ikigai}/PKGBUILD"
  bash -n "$f" && grep -q "^pkgname=$p\$" "$f" || { echo "$p: no $f with pkgname=$p"; exit 1; }
done
echo "${#ours[@]} ikigai package(s) have a PKGBUILD"

for p in nvidia-open-dkms nvidia-utils linux-headers mesa vulkan-radeon vulkan-intel hyperv; do
  pacman -Si "$p" >/dev/null
done
echo "gpu/vm packages resolve"

# The Qt Wayland patch must parse (git apply) and apply to the qwaylandwindow.cpp of the
# qt6-base Arch ships right now; a miscounted hunk or upstream drift fails every fresh install.
[ "$(id -u)" -eq 0 ] && pacman -S --noconfirm --needed git patch >/dev/null
qt_patch=packages/qt6-base/wayland-unmap-before-role-destroy.patch
git apply --numstat "$qt_patch" >/dev/null
qt_ver=$(pacman -Si qt6-base | awk '/^Version/ { print $3 }'); qt_ver=${qt_ver%-*}
qt_tmp=$(mktemp -d) && trap 'rm -rf "$qt_tmp"' EXIT
mkdir -p "$qt_tmp/src/plugins/platforms/wayland"
curl -fsSL -o "$qt_tmp/src/plugins/platforms/wayland/qwaylandwindow.cpp" \
  "https://raw.githubusercontent.com/qt/qtbase/v$qt_ver/src/plugins/platforms/wayland/qwaylandwindow.cpp"
patch -d "$qt_tmp" -p1 --forward --dry-run < "$qt_patch" >/dev/null
echo "qt6-base $qt_ver: wayland patch applies"

[ "$(id -u)" -eq 0 ] && pacman -S --noconfirm --needed rust pkgconf libxkbcommon >/dev/null
(cd session && cargo test --locked -q && cargo clippy --locked -q --all-targets -- -D warnings)
echo "session crate ok"

find themes config -type f \( -name '*.ron' -o -path '*/v[0-9]/*' \) | while read -r f; do
  grep -q . "$f" || { echo "empty config file: $f"; exit 1; }
done
echo "config files non-empty"

python -c '
import json; d = json.load(open("archinstall.json"))
assert d["profile_config"]["profile"]["main"] == "Minimal"
assert d["bootloader_config"]["bootloader"] == "Systemd-boot"
assert d["network_config"]["type"] == "nm"
assert any("boot.sh" in c for c in d["custom_commands"])
'
echo "archinstall.json ok"

python -c '
import json, glob
for f in ["config/ikigai/shell.json", "config/zen/policies.json", *glob.glob("themes/*/shell.json")]: json.load(open(f))
'
echo "json configs ok"

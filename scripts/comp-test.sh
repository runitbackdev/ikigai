#!/usr/bin/env bash
# The layer-shell regression test for the cosmic-comp fork (`just comp-test [binary]`).
# Runs scripts/comp-test/hide.qml (a layer window shown and hidden six times) and lock.qml
# (two ext-session-lock cycles) as Quickshell under a nested cosmic-comp, with the *stock*
# Qt Wayland client. On a compositor without the smithay fix (smithay#1979) the client dies
# on the first hide and the first unlock; on the fork both run to "survived".
set -euo pipefail

comp=${1:-cosmic-comp}
here=$(cd "$(dirname "$0")" && pwd)
[ -n "${WAYLAND_DISPLAY:-}" ] || { echo "comp-test: not inside a Wayland session" >&2; exit 1; }
command -v qs >/dev/null || { echo "comp-test: quickshell not installed" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# Ikigai's Qt patch hides the bug from the client side; the test needs the library as Arch ships it.
lib=/usr/lib
if ! pacman -Qkk qt6-base >/dev/null 2>&1; then
  ver=$(pacman -Q qt6-base | cut -d' ' -f2)
  pkg=$(ls -1 /var/cache/pacman/pkg/qt6-base-"$ver"-x86_64.pkg.tar.zst 2>/dev/null | head -1)
  [ -n "$pkg" ] || { echo "comp-test: qt6-base is patched and $ver is not in the pacman cache; pacman -Sw qt6-base" >&2; exit 1; }
  tar -C "$tmp" --zstd -xf "$pkg" usr/lib/libQt6WaylandClient.so usr/lib/libQt6WaylandClient.so.6 "usr/lib/libQt6WaylandClient.so.${ver%-*}"
  lib=$tmp/usr/lib
  echo "stock Qt Wayland client from $pkg"
fi

fail=0
for t in hide lock; do
  if timeout 30 "$comp" --no-xwayland env QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME='' LD_LIBRARY_PATH="$lib" \
       qs -p "$here/comp-test/$t.qml" >"$tmp/$t.log" 2>&1 && grep -q survived "$tmp/$t.log"; then
    echo "ok   $t: $(grep -o 'survived.*' "$tmp/$t.log" | sed 's/, exiting 0//')"
  else
    echo "FAIL $t: $(grep -a 'broke\|error' "$tmp/$t.log" | tail -1 | sed 's/\x1b\[[0-9;]*m//g; s/^ *//')"; fail=1
  fi
done
exit $fail

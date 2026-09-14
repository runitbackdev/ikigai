#!/usr/bin/env bash
# The greeter from this working tree in a nested cosmic-comp window (`just greeter`):
# the same command greetd runs, minus greetd. Password entry is real PAM, so a correct
# password makes the card succeed and cosmic-comp exit, which is the test. Theme and
# wallpaper come from the system profile's share/ikigai/theme, the installed theme's.
set -euo pipefail

tree="$(cd "$(dirname "$0")/.." && pwd)"
[ -n "${WAYLAND_DISPLAY:-}" ] || { echo "dev-greeter: not inside a Wayland session" >&2; exit 1; }

export QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME='' QML_IMPORT_PATH=${IKIGAI_QML:-/run/current-system/sw/lib/qt6/qml}
export IKIGAI_THEME_FILE=/run/current-system/sw/share/ikigai/theme/shell.json
# cosmic-comp picks the winit backend on its own when a parent Wayland display is set.
exec cosmic-comp --no-xwayland qs -p "$tree/shell/greeter.qml" "$@"

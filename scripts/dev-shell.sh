#!/usr/bin/env bash
# Run the shell from this working tree in place of the installed one (`just shell`).
# Stops ikigai-shell.service, runs qs on shell/shell.qml with Quickshell's file watcher
# on (edits reload live), logs to this terminal, and brings the unit back on exit. The
# path lands in $XDG_RUNTIME_DIR/ikigai/dev-shell so `ikigai-shell` (cosmic-comp's
# shortcuts) and `ikigai-shot` talk to this instance instead.
set -euo pipefail

tree="$(cd "$(dirname "$0")/.." && pwd)"
qml="$tree/shell/shell.qml"
run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ikigai"
dev="$run/dev-shell"

[ -n "${WAYLAND_DISPLAY:-}" ] || { echo "dev-shell: not inside a Wayland session" >&2; exit 1; }
[ -r "$dev" ] && { echo "dev-shell: already running from $(cat "$dev")" >&2; exit 1; }

# The plugins come from the system profile (ikigai-shell-plugins); only the QML is live.
# A plugin change is a rebuild: `just build ikigai-shell-plugins`, then ikigai-update.
plugin=${IKIGAI_QML:-/run/current-system/sw/lib/qt6/qml}
[ -d "$plugin/Ikigai" ] || echo "dev-shell: no plugin under $plugin (IKIGAI_QML to point elsewhere)" >&2

was_active=0
systemctl --user -q is-active ikigai-shell.service && was_active=1
mkdir -p "$run"
echo "$qml" > "$dev"
cleanup() {
  rm -f "$dev"
  [ "$was_active" = 1 ] && systemctl --user start ikigai-shell.service
  echo "dev-shell: stopped; installed shell $([ "$was_active" = 1 ] && echo restarted || echo left as it was)"
}
trap cleanup EXIT

[ "$was_active" = 1 ] && systemctl --user stop ikigai-shell.service
echo "dev-shell: running $qml (Ctrl+C to stop)"
QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME='' QML_IMPORT_PATH="$plugin" \
  qs -p "$qml" "$@"

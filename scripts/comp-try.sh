#!/usr/bin/env bash
# A client under a build of the compositor fork, nested in a window (`just comp-try
# [binary] [command...]`), with this tree's compositor config and cursor theme. For
# trying a fork change by hand before it ships; `just comp-test` is the automated one.
# The nested window keeps the host's arrow on top of the fork's own cursor. libcosmic apps
# fork at startup and the first process exits, which ends a kiosk session: use Ghostty.
set -euo pipefail
comp=${1:-cosmic-comp}; shift || true
tree=$(cd "$(dirname "$0")/.." && pwd)
cfg=$(mktemp -d); trap 'rm -rf "$cfg"' EXIT
cp -r "$tree/config/cosmic/." "$cfg/cosmic/"
export XDG_CONFIG_HOME=$cfg XCURSOR_PATH=$tree/themes/ikigai/cursors XCURSOR_THEME=Ikigai XCURSOR_SIZE=24 RUST_BACKTRACE=1
exec "$comp" --no-xwayland "${@:-ghostty}"

#!/usr/bin/env bash
set -euo pipefail

export IKIGAI_PATH="${IKIGAI_PATH:-$HOME/.local/share/ikigai}"
export IKIGAI_STATE="${IKIGAI_STATE:-$HOME/.local/state/ikigai}"
mkdir -p "$IKIGAI_STATE"
LOG="$IKIGAI_STATE/install.log"

STEPS=(preflight packages configs tools theme services firewall session greeter)
TOTAL=${#STEPS[@]}
TAIL=20

# The live step list needs a terminal someone is watching. archinstall runs the installer on
# a pty that has no window size (its log captures the output); IKIGAI_PLAIN=1 forces plain lines.
ui='plain'
rows=$(stty size 2>/dev/null </dev/tty || echo 0)
if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "$TERM" != dumb ] && [ "${rows%% *}" -gt 0 ] && [ "${IKIGAI_PLAIN:-0}" != 1 ]; then
  ui='tty'
  bold=$(tput bold) dim=$(tput dim) green=$(tput setaf 2) red=$(tput setaf 1) reset=$(tput sgr0)
fi

log() { printf '%s\n' "$*" >> "$LOG"; }
say() { printf '%s\n' "$*"; log "$*"; }
elapsed() { local s=$(( EPOCHSECONDS - $1 )); [ "$s" -ge 60 ] && printf '%dm%02ds' $((s / 60)) $((s % 60)) || printf '%ds' "$s"; }

# Repaints the current step and the log's last line until killed. Everything the step prints
# goes to the log, so a stuck build still shows its last line here and nothing is lost.
spin() {
  local n=$1 name=$2 start=$3 frames="|/-\\" i=0 line cols
  while :; do
    cols=$(tput cols 2>/dev/null || echo 80)
    line=$(tail -n1 "$LOG" 2>/dev/null | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g'); line=${line##*$'\r'}
    printf '\r  %s   %-10s %2d/%d  %6s\e[K\r\n      %s%.*s%s\e[K\e[1A' \
      "${frames:i++ % 4:1}" "$name" "$n" "$TOTAL" "$(elapsed "$start")" "$dim" $((cols - 6)) "$line" "$reset"
    sleep 0.2
  done
}

# The step's slice of the log, progress bars reduced to their final state.
failure_tail() { tail -c +"$(( $1 + 1 ))" "$LOG" | sed 's/.*\r//' | tail -n "$TAIL" | sed 's/^/  /'; }

run_step() {
  local n=$1 name=$2 start=$EPOCHSECONDS offset rc=0
  if [ "$ui" = tty ]; then
    log "==> [$n/$TOTAL] $name"
    offset=$(stat -c %s "$LOG")
    spin "$n" "$name" "$start" & SPINNER=$!
    bash "$IKIGAI_PATH/install/$name.sh" >> "$LOG" 2>&1 || rc=$?
    kill "$SPINNER" 2>/dev/null || true; wait "$SPINNER" 2>/dev/null || true
    SPINNER=
    if [ "$rc" -eq 0 ]; then
      printf '\r  %sok%s  %-10s        %6s\e[K\r\n\e[K' "$green" "$reset" "$name" "$(elapsed "$start")"
    else
      printf '\r  %sFAILED%s  %-10s %2d/%d  %6s\e[K\r\n\e[K\r\n' "$red" "$reset" "$name" "$n" "$TOTAL" "$(elapsed "$start")"
    fi
  else
    say "==> [$n/$TOTAL] $name"
    offset=$(stat -c %s "$LOG")
    bash "$IKIGAI_PATH/install/$name.sh" 2>&1 | tee -a "$LOG" || rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    log "==> [$n/$TOTAL] $name ok $(elapsed "$start")"
    [ "$ui" = plain ] && say "==> [$n/$TOTAL] $name ok $(elapsed "$start")"
    return 0
  fi
  [ "$ui" = plain ] && echo
  failure_tail "$offset"
  say "!!! install failed in step '$name' after $(elapsed "$start") (see $LOG)"
  exit "$rc"
}

sudo true
( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
SPINNER=
cleanup() {
  set +e
  [ -n "$SPINNER" ] && { kill "$SPINNER" 2>/dev/null; echo; }
  kill "$SUDO_KEEPALIVE" 2>/dev/null
  [ "$ui" = tty ] && tput cnorm
}
trap cleanup EXIT

commit="$(git -C "$IKIGAI_PATH" rev-parse HEAD 2>/dev/null || echo unversioned)"
echo "$commit" > "$IKIGAI_STATE/installed_commit"
[ "$commit" = unversioned ] || commit=${commit:0:7}
log "ikigai install $(date -Is) — $commit"
if [ "$ui" = tty ]; then
  tput civis
  printf '%sikigai install%s  %s\n\n' "$bold" "$reset" "$commit"
else
  echo "ikigai install $(date -Is) — $commit"
fi

start=$EPOCHSECONDS
n=0
for name in "${STEPS[@]}"; do
  run_step $((++n)) "$name"
done

echo
say "==> Ikigai installed in $(elapsed "$start"). Reboot into Ikigai:  sudo reboot"

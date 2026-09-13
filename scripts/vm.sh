#!/usr/bin/env bash
# Drive a QEMU/KVM VM from an Arch host for fresh-install testing (`just vm ...`).
# Same lifecycle as the Hyper-V harness it replaces (scripts/vm-hyperv.sh, for WSL2):
#   fetch → create → install → seal → run / reset
# The disk is a qcow2 with a sealed read-only base: `seal` freezes the vanilla install
# as base.qcow2 and every run happens on an overlay; `reset` throws the overlay away.
# Networking is user-mode (no bridge, no root): ssh via a forwarded port, the guest
# reaches this host at 10.0.2.2. Needs: qemu-desktop edk2-ovmf (pacman); ffmpeg for record.
set -euo pipefail

VM=${VM_NAME:-ikigai}
CPUS=${VM_CPUS:-4}
MEM=${VM_MEM:-4G}
DISK_SIZE=${VM_DISK:-40G}
SSH_PORT=${VM_SSH_PORT:-2222}
OUTPUTS=${VM_OUTPUTS:-1}          # virtual monitors; 2 exercises the multi-output paths
DISPLAY_KIND=${VM_DISPLAY:-gtk}   # gtk | sdl | none (headless: ssh + screenshot only)
ISO_MIRROR="https://geo.mirror.pkgbuild.com/iso/latest"
ARCH_RELEASE_KEY=3E80CA1A8B89F69CBA57D98A76A5EF9054449A5C

VM_DIR="${VM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/ikigai-vm}"
ISO="$VM_DIR/archlinux-x86_64.iso"
BASE="$VM_DIR/$VM.base.qcow2"       # sealed vanilla install (read-only backing file)
DISK="$VM_DIR/$VM.qcow2"            # the disk that runs: standalone before seal, overlay after
OVMF_CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
OVMF_VARS_SRC=/usr/share/edk2/x64/OVMF_VARS.4m.fd
VARS="$VM_DIR/$VM.vars.fd"; VARS_BASE="$VM_DIR/$VM.base.vars.fd"
PIDFILE="$VM_DIR/$VM.pid"; QMP="$VM_DIR/$VM.qmp"; SERIAL="$VM_DIR/$VM.serial.log"
SSH_KEY="$HOME/.ssh/ikigai-vm"
# Host-key checking is off on purpose: this only ever talks to the throwaway VM.
SSH_OPTS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p "$SSH_PORT")

die() { echo "vm.sh: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "$1 not installed${2:+ (pacman -S $2)}"; }
vm_exists()  { [ -f "$DISK" ]; }
vm_running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }
sealed()     { [ -f "$BASE" ]; }

# One JSON command to QEMU's monitor socket; prints the reply.
qmp() {
  need python3
  python3 - "$QMP" "$@" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile("rw")
f.readline(); f.write('{"execute":"qmp_capabilities"}\n'); f.flush(); f.readline()
f.write(json.dumps({"execute": sys.argv[2], "arguments": json.loads(sys.argv[3] if len(sys.argv) > 3 else "{}")}) + "\n"); f.flush()
while True:
    r = json.loads(f.readline())
    if "return" in r or "error" in r:
        print(json.dumps(r)); sys.exit(1 if "error" in r else 0)
PY
}

cmd_fetch() {
  mkdir -p "$VM_DIR"
  curl -fL --progress-bar -o "$ISO" "$ISO_MIRROR/archlinux-x86_64.iso"
  curl -fsSL -o "$ISO.sig" "$ISO_MIRROR/archlinux-x86_64.iso.sig"
  gpg --auto-key-locate clear,wkd -v --locate-external-key pierre@archlinux.org >/dev/null 2>&1
  gpg --status-fd 1 --verify "$ISO.sig" "$ISO" 2>/dev/null | grep -q "VALIDSIG $ARCH_RELEASE_KEY" \
    || die "ISO signature verification failed (expected Arch release key $ARCH_RELEASE_KEY)"
  echo "fetched + verified $ISO"
}

cmd_create() {
  need qemu-img qemu-desktop; [ -f "$OVMF_CODE" ] || die "no OVMF at $OVMF_CODE (pacman -S edk2-ovmf)"
  mkdir -p "$VM_DIR"
  vm_exists && die "VM '$VM' already exists (vm.sh destroy to start over)"
  qemu-img create -q -f qcow2 "$DISK" "$DISK_SIZE"
  cp "$OVMF_VARS_SRC" "$VARS"
  echo "created VM '$VM' ($CPUS cpu, $MEM, $DISK_SIZE) in $VM_DIR"
}

# The QEMU command line. Secure Boot is off (no signed shim; same as the Hyper-V harness).
start_qemu() {
  need qemu-system-x86_64 qemu-desktop
  vm_exists || die "no VM; run: vm.sh create"
  vm_running && die "VM already running (pid $(cat "$PIDFILE"))"
  # shellcheck disable=SC2054
  local args=(
    -name "$VM" -enable-kvm -machine q35,accel=kvm -cpu host -smp "$CPUS" -m "$MEM"
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$VARS"
    -drive "file=$DISK,if=virtio,format=qcow2,discard=unmap"
    -device "virtio-vga-gl,max_outputs=$OUTPUTS"
    -device virtio-keyboard-pci -device virtio-tablet-pci
    -device intel-hda -device hda-duplex
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" -device virtio-net-pci,netdev=net0
    -device virtio-rng-pci
    -chardev "socket,id=qmp,path=$QMP,server=on,wait=off" -mon chardev=qmp,mode=control
    -serial "file:$SERIAL"
    -pidfile "$PIDFILE" -daemonize
  )
  case "$DISPLAY_KIND" in
    none) args+=(-display none) ;;
    *) args+=(-display "$DISPLAY_KIND,gl=on") ;;
  esac
  qemu-system-x86_64 "${args[@]}" "$@"
}

cmd_install() {
  [ -f "$ISO" ] || die "no ISO; run: vm.sh fetch"
  start_qemu -cdrom "$ISO" -boot d
  cat <<MSG
booted the Arch ISO. In the guest:
  archinstall --config-url https://raw.githubusercontent.com/runitbackdev/ikigai/main/archinstall.json
or to install from this working tree instead: vm.sh serve, then inside the guest
  archinstall --config-url http://10.0.2.2:${VM_HTTP_PORT:-8642}/archinstall.json
When it is done: poweroff the guest, then vm.sh seal.
MSG
}

# Serve this checkout to the guest (10.0.2.2) as a git repo over dumb HTTP, with an
# archinstall.json whose post-install command clones it instead of GitHub. What is
# committed on the current branch is what installs; uncommitted work goes over with sync.
cmd_serve() {
  local port="${VM_HTTP_PORT:-8642}" tree out ref
  tree="$(cd "$(dirname "$0")/.." && pwd)"; ref="$(git -C "$tree" rev-parse --abbrev-ref HEAD)"
  out="$VM_DIR/serve"; rm -rf "$out"; mkdir -p "$out"
  git clone -q --bare "$tree" "$out/ikigai.git" && git -C "$out/ikigai.git" update-server-info
  python3 - "$tree/archinstall.json" "$out/archinstall.json" "$port" "$ref" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); port, ref = sys.argv[3], sys.argv[4]
d["custom_commands"] = [c.replace(
    "export IKIGAI_PLAIN=1;",
    f"export IKIGAI_PLAIN=1 IKIGAI_REPO=http://10.0.2.2:{port}/ikigai.git IKIGAI_REF={ref};")
    .replace("https://raw.githubusercontent.com/runitbackdev/ikigai/main/boot.sh", f"http://10.0.2.2:{port}/boot.sh")
    for c in d["custom_commands"]]
json.dump(d, open(sys.argv[2], "w"), indent=2)
PY
  cp "$tree/boot.sh" "$out/"
  echo "serving $tree ($ref) at http://127.0.0.1:$port (guest: http://10.0.2.2:$port); Ctrl+C to stop"
  python3 -m http.server -d "$out" -b 127.0.0.1 "$port"
}

cmd_seal() {
  vm_exists || die "no VM"
  vm_running && die "shut the VM down first"
  if sealed; then
    [ "${1:-}" = --force ] || die "already sealed (--force replaces the base with the current disk)"
    qemu-img rebase -q -f qcow2 -b "" "$DISK"   # fold overlay into a standalone disk
    rm -f "$BASE" "$VARS_BASE"
  fi
  mv "$DISK" "$BASE"; cp "$VARS" "$VARS_BASE"
  qemu-img create -q -f qcow2 -F qcow2 -b "$BASE" "$DISK"
  echo "sealed: $BASE is the vanilla base; runs happen on $DISK"
}

cmd_reset() {
  vm_exists || die "no VM"; sealed || die "not sealed yet (vm.sh seal)"
  vm_running && cmd_kill
  local name="${1:-vanilla}"
  if [ "$name" = vanilla ]; then
    rm -f "$DISK"; qemu-img create -q -f qcow2 -F qcow2 -b "$BASE" "$DISK"; cp "$VARS_BASE" "$VARS"
  else
    qemu-img snapshot -q -a "$name" "$DISK"; [ -f "$VARS.$name" ] && cp "$VARS.$name" "$VARS"
  fi
  echo "restored '$name'"
}

cmd_run()  { start_qemu "$@"; echo "running (pid $(cat "$PIDFILE")); ssh: vm.sh ssh, screen: vm.sh screenshot"; }
cmd_stop() { vm_running || die "not running"; qmp system_powerdown >/dev/null; echo "powerdown sent"; }
cmd_kill() { vm_running || die "not running"; qmp quit >/dev/null 2>&1 || kill "$(cat "$PIDFILE")"; rm -f "$PIDFILE"; echo "killed"; }
cmd_status() {
  vm_exists || { echo "no VM"; return; }
  printf '%s: %s\n' "$VM" "$(vm_running && echo "running (pid $(cat "$PIDFILE"))" || echo off)"
  printf 'disk: %s%s\n' "$DISK" "$(sealed && echo " (overlay on $BASE)")"
  qemu-img info "$DISK" | grep -E '^(virtual size|disk size)'
}
cmd_serial() { touch "$SERIAL"; tail -f "$SERIAL"; }

cmd_key() {
  local user="${1:?user}" pub
  [ -f "$SSH_KEY" ] || ssh-keygen -q -t ed25519 -N "" -f "$SSH_KEY" -C ikigai-vm
  pub="$(cat "$SSH_KEY.pub")"
  ssh "${SSH_OPTS[@]}" "$user@127.0.0.1" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF '$pub' ~/.ssh/authorized_keys 2>/dev/null || echo '$pub' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys && echo key installed"
}
cmd_ssh() { local user="${1:-root}"; shift || true; ssh "${SSH_OPTS[@]}" "$user@127.0.0.1" "$@"; }

# Copy the working tree into the VM at ~/.local/share/ikigai, keeping the guest's build
# caches. `sync <user> <step>` then runs that install step there.
cmd_sync() {
  local user="${1:?user}" step="${2:-}" dest=".local/share/ikigai"
  git -C "$(dirname "$0")/.." ls-files -z --cached --others --exclude-standard \
    | tar --null -T - -czf - \
    | ssh "${SSH_OPTS[@]}" "$user@127.0.0.1" "keep=\$(mktemp -d); [ -d $dest/tools ] && find $dest/tools -maxdepth 2 -name target -type d -exec cp -a --parents {} \$keep \; ; rm -rf $dest && mkdir -p $dest && tar -xzf - -C $dest && cp -a \$keep/$dest/tools/. $dest/tools/ 2>/dev/null; rm -rf \$keep; echo synced"
  [ -n "$step" ] && ssh -t "${SSH_OPTS[@]}" "$user@127.0.0.1" "IKIGAI_PATH=\$HOME/$dest IKIGAI_STATE=\$HOME/.local/state/ikigai bash \$HOME/$dest/install/$step.sh"
}

cmd_screenshot() {
  local out="${1:-$VM_DIR/$VM.png}"
  vm_running || die "VM is not running"
  qmp screendump "{\"filename\":\"$out\",\"format\":\"png\"}" >/dev/null
  echo "screenshot: $out ($(file -b "$out" | grep -o '[0-9]* x [0-9]*' | tr -d ' '))"
}

# screendump at ~10 fps into a GIF; QEMU's dump is a full frame each time, so the rate
# is bounded by disk, not the guest.
cmd_record() {
  local secs="${1:?seconds}" out="${2:-$VM_DIR/$VM.gif}" tmp i=0 end
  vm_running || die "VM is not running"; need ffmpeg ffmpeg
  tmp="$(mktemp -d)"; end=$((EPOCHSECONDS + secs))
  while [ "$EPOCHSECONDS" -lt "$end" ]; do
    qmp screendump "{\"filename\":\"$tmp/$(printf f%05d $i).ppm\"}" >/dev/null; i=$((i + 1)); sleep 0.1
  done
  ffmpeg -v error -y -framerate 10 -i "$tmp/f%05d.ppm" \
    -vf "split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$out"
  rm -rf "$tmp"
  echo "record: $out ($(du -h "$out" | cut -f1), $i frames over ${secs}s)"
}

cmd_snapshot()  { vm_running && die "shut the VM down first"; qemu-img snapshot -q -c "${1:?name}" "$DISK"; cp "$VARS" "$VARS.$1"; echo "snapshot '$1'"; }
cmd_snapshots() { sealed && echo "vanilla (base)"; qemu-img snapshot -l "$DISK" | tail -n +3 | awk '{print $2, $4, $5}'; }

cmd_destroy() {
  vm_exists || die "no VM"
  vm_running && cmd_kill
  rm -f "$DISK" "$BASE" "$VARS" "$VARS_BASE" "$VARS".* "$QMP" "$PIDFILE" "$SERIAL"
  echo "destroyed VM '$VM' (ISO kept in $VM_DIR)"
}

usage() {
  cat <<USAGE
usage: vm.sh <command>
  fetch                 download + verify Arch ISO
  create                create the disk ($DISK_SIZE) and firmware vars
  install               boot the ISO (then run archinstall in the guest)
  serve                 serve this working tree to the guest for an install from it
  seal [--force]        freeze the current disk as the vanilla base (VM must be off)
  reset [name]          roll back to a snapshot (default: vanilla)
  run                   start the VM
  stop | kill           ACPI powerdown | hard power off
  status                state and disk usage
  serial                follow the guest's serial console log
  key <user>            install a host ssh key in the VM (do this before sync)
  ssh [user] [cmd]      ssh into the VM (port $SSH_PORT)
  sync <user> [step]    copy this working tree to ~/.local/share/ikigai; then run install/<step>.sh there
  screenshot [file]     save the guest display as PNG (default: VM dir)
  record <s> [file]     capture the guest display for <s> seconds as a GIF
  snapshot <name>       take a snapshot (VM must be off)
  snapshots             list snapshots
  destroy               remove the VM's disks
env: VM_NAME=$VM VM_CPUS=$CPUS VM_MEM=$MEM VM_DISK=$DISK_SIZE VM_SSH_PORT=$SSH_PORT VM_OUTPUTS=$OUTPUTS VM_DISPLAY=$DISPLAY_KIND
VM dir: $VM_DIR
USAGE
}

case "${1:-}" in
  fetch|create|install|serve|stop|kill|status|serial|snapshots|destroy) "cmd_$1" ;;
  run) shift; cmd_run "$@" ;;
  ssh) shift; cmd_ssh "$@" ;;
  reset|snapshot|seal|key|screenshot) "cmd_$1" "${2:-}" ;;
  sync) cmd_sync "${2:-}" "${3:-}" ;;
  record) cmd_record "${2:-}" "${3:-}" ;;
  *) usage; exit 1 ;;
esac

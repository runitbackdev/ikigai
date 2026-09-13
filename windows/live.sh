#!/usr/bin/env bash
# The Arch ISO half of boot.ps1. archiso runs this on tty1 from the script= kernel
# parameter in the loader entry boot.ps1 wrote. It finds the disk the ISO was staged
# on, writes an archinstall config for it and runs archinstall, whose custom command
# is Ikigai's own installer. Windows is erased here, at archinstall's disk step.
set -euo pipefail

say() { printf '\e[36m==> %s\e[0m\n' "$*"; }
die() { printf '\e[31mlive.sh: %s\e[0m\n' "$*" >&2; exit 1; }
param() { sed -n "s/.*[[:space:]]$1=\([^[:space:]]*\).*/\1/p" /proc/cmdline; }

mode="$(param ikigai.mode)"
ref="${IKIGAI_REF:-$(param ikigai.ref)}"; ref="${ref:-main}"
raw="${IKIGAI_RAW:-$(param ikigai.raw)}"; raw="${raw:-https://raw.githubusercontent.com/runitbackdev/ikigai/$ref}"
label="$(param img_label)"

[ "$(id -u)" = 0 ] || die "run as root"
[ -n "$mode" ] || die "no ikigai.mode on the kernel command line"
stage="$(readlink -f "/dev/disk/by-label/$label")" || die "no partition labelled $label"
disk="/dev/$(lsblk -no pkname "$stage")"
[ -b "$disk" ] || die "cannot find the disk behind $stage"
lsblk -no mountpoints "$disk" | grep -q . && die "$disk is still in use; was copytoram on?"

until curl -fsS -m 10 -o /dev/null https://archlinux.org; do
  say "No internet. In iwctl: station wlan0 connect <network>, then exit."
  iwctl || true
done

# archinstall wants every partition spelled out: 1 MiB aligned, in this order, clear of
# the backup GPT header at the end. Sizes in MiB keep the arithmetic honest.
partition() {
  local start=$1 size=$2 fs=$3 mount=$4 flags=$5
  jq -cn --arg id "$(uuidgen)" --arg start "$start" --arg size "$size" --arg fs "$fs" --arg mount "$mount" --argjson flags "$flags" '{
    obj_id: $id, status: "create", type: "primary",
    start: { value: ($start | tonumber), unit: "MiB", sector_size: { value: 512, unit: "B" } },
    size:  { value: ($size | tonumber),  unit: "MiB", sector_size: { value: 512, unit: "B" } },
    fs_type: $fs, mountpoint: $mount, mount_options: [], flags: $flags, btrfs: [], dev_path: null }'
}

replace_layout() {
  local total boot_mib=1024
  total=$(( $(blockdev --getsize64 "$disk") / 1048576 ))
  jq -cn --arg disk "$disk" \
    --argjson boot "$(partition 1 $boot_mib fat32 /boot '["boot","esp"]')" \
    --argjson root "$(partition $((1 + boot_mib)) $((total - boot_mib - 2)) ext4 / '[]')" \
    '{ config_type: "manual_partitioning", device_modifications: [ { device: $disk, wipe: true, partitions: [$boot, $root] } ] }'
}

# Keep Windows: drop the staging partition, then put a 1 GiB /boot and the root in the
# largest free region. Windows' own ESP becomes /efi, untouched: systemd-boot fits in
# it, kernels do not, so /boot is a separate XBOOTLDR partition. Every Windows
# partition is listed as existing so archinstall leaves it alone.
dual_layout() {
  local start end boot_mib=1024 existing
  sfdisk --delete "$disk" "$(cat "/sys/class/block/$(basename "$stage")/partition")" >/dev/null
  udevadm settle
  read -r start end < <(sfdisk -F "$disk" | awk '$1 ~ /^[0-9]+$/ && $3 > best { best = $3; s = $1; e = $2 } END { print s, e }')
  start=$(( (start * 512 + 1048575) / 1048576 ))
  end=$(( end * 512 / 1048576 ))
  existing=$(lsblk -Jb -o PATH,START,SIZE,FSTYPE,PARTTYPE "$disk" | jq -c --arg esp c12a7328-f81f-11d2-ba4b-00a0c93ec93b '
    [ .blockdevices[] | select(.start != null) | {
        obj_id: .path, status: "existing", type: "primary",
        start: { value: (.start * 512), unit: "B", sector_size: { value: 512, unit: "B" } },
        size:  { value: .size,          unit: "B", sector_size: { value: 512, unit: "B" } },
        fs_type: (if .fstype == "vfat" then "fat32" elif .fstype == "ntfs" then "ntfs" else null end),
        mountpoint: (if .parttype == $esp then "/efi" else null end),
        mount_options: [], flags: (if .parttype == $esp then ["esp"] else [] end), btrfs: [], dev_path: .path } ]')
  jq -cn --arg disk "$disk" --argjson existing "$existing" \
    --argjson boot "$(partition "$start" $boot_mib fat32 /boot '["boot","xbootldr"]')" \
    --argjson root "$(partition $((start + boot_mib)) $((end - start - boot_mib - 1)) ext4 / '[]')" \
    '{ config_type: "manual_partitioning", device_modifications: [ { device: $disk, wipe: false, partitions: ($existing + [$boot, $root]) } ] }'
}

case "$mode" in
  replace) layout="$(replace_layout)" ;;
  dual) layout="$(dual_layout)" ;;
  *) die "unknown mode $mode" ;;
esac

say "Ikigai will install on $disk ($(lsblk -dno size,model "$disk" | xargs)), mode: $mode"
config=/tmp/ikigai.json
curl -fsSL "$raw/archinstall.json" \
  | jq --argjson layout "$layout" --arg ref "$ref" '
      .disk_config = $layout
      | .custom_commands |= map(gsub("/ikigai/main/"; "/ikigai/\($ref)/") | sub("IKIGAI_PLAIN=1;"; "IKIGAI_PLAIN=1; export IKIGAI_REF=\($ref);"))' \
  > "$config"

say "archinstall: set a user and password and your timezone, then Install"
archinstall --config "$config"
[ -f /mnt/etc/fstab ] || die "nothing was installed. 'reboot' brings Windows back; run boot.ps1 again from there"

# The one-shot entry boot.ps1 registered points at a partition that no longer exists.
efibootmgr | sed -n 's/^Boot\([0-9A-F]*\)\* Ikigai installer.*/\1/p' | xargs -rI{} efibootmgr -q -b {} -B

lsblk -o name,size,fstype,label,mountpoints "$disk"
say "Done. 'reboot' when ready."

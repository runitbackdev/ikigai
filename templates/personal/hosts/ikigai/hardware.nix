# Written by nixos-generate-config at install: the disks, the kernel modules the hardware
# needs, the CPU's microcode. Regenerate with
# `nixos-generate-config --show-hardware-config` after a hardware change.
{ ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };
}

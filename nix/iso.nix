# The installer ISO: NixOS's minimal image with the Ikigai installer on tty1. From a USB
# stick, or staged on a partition by boot.ps1 from Windows: its GRUB finds the volume by the
# IKIGAI label and the kernel its root the same way, so a FAT32 partition of that label
# holding the ISO's files boots too. `nix build .#iso`; CI publishes it to the `iso` release.
{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ./installer/live.nix
  ];

  isoImage = {
    volumeID = "IKIGAI";
    squashfsCompression = "zstd -Xcompression-level 15";
  };
  image.baseName = lib.mkForce "ikigai-x86_64";
  image.fileName = lib.mkForce "ikigai-x86_64.iso";
  # Staged on a FAT32 partition (boot.ps1), the root filesystem is vfat.
  boot.initrd.availableKernelModules = [
    "vfat"
    "nls_cp437"
    "nls_iso8859-1"
  ];
}

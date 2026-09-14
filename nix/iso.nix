# The installer ISO: NixOS's minimal image with the Ikigai installer on tty1. From a USB
# stick, or staged on a partition by boot.ps1 from Windows: its GRUB finds the volume by the
# IKIGAI label and the kernel its root the same way, so a FAT32 partition of that label
# holding the ISO's files boots too. `nix build .#iso`; CI publishes it to the `iso` release.
{
  config,
  lib,
  pkgs,
  modulesPath,
  self,
  ...
}:
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

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

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  # The flake this ISO was built from, for an offline-ish install and a matching lock.
  environment.etc."ikigai".source = self;
  environment.systemPackages = with pkgs; [
    (pkgs.callPackage ./installer/package.nix { })
    git
    jq
    curl
    gptfdisk
    parted
    efibootmgr
    mkpasswd
    dosfstools
    e2fsprogs
    util-linux
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://ikigai-desktop.cachix.org" ];
    trusted-public-keys = [ "ikigai-desktop.cachix.org-1:REPLACE_WITH_THE_KEY_FROM_APP_CACHIX_ORG" ];
  };

  # Root logs in on tty1 and the installer runs; a second console stays plain.
  services.getty.autologinUser = lib.mkForce "root";
  programs.bash.interactiveShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ ! -e /run/ikigai-install-started ]; then
      touch /run/ikigai-install-started
      ikigai-install || echo "ikigai-install failed; run it again, or poke around"
    fi
  '';
}

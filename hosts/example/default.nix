# The example host: what CI builds, what `nix run .#vm` boots, and the shape a personal
# flake copies (templates/personal). No hardware file: the VM makes its own, and a real
# box gets one from nixos-generate-config.
{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  ikigai = {
    enable = true;
    user = "ikigai";
    gpu = "none";
  };
  users.users.ikigai.initialPassword = "ikigai";

  networking.hostName = "ikigai-example";
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  # The QEMU VM (`nix run .#vm`): a virtio GPU with GL so cosmic-comp renders through
  # virgl rather than llvmpipe, and enough RAM for a Rust build inside.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 20480;
      qemu.options = [
        "-device virtio-vga-gl"
        "-display gtk,gl=on"
      ];
    };
    # No EFI variables to touch in the VM's firmware.
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  };

  system.stateVersion = "25.11";
}

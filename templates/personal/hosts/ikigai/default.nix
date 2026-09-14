# This box. What ikigai-install asked for is here; everything else is Ikigai's default and
# has an option (github:runitbackdev/ikigai, nix/ikigai/default.nix). Rebuild with
# `ikigai-update`, or `sudo nixos-rebuild switch --flake /etc/nixos`.
{ ... }:
{
  imports = [ ./hardware.nix ];

  ikigai = {
    enable = true;
    user = "lycanthropy";
    gpu = "nvidia";
    steam.enable = false;
  };

  networking.hostName = "ikigai";
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # The NixOS release this box was first installed with. Never change it.
  system.stateVersion = "25.11";
}

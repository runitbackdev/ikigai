# Nix itself: flakes, the binary cache CI fills, weekly garbage collection in place of
# paccache, and the wheel group allowed to use the cache from a rebuild.
{
  config,
  lib,
  ...
}:
let
  cfg = config.ikigai;
in
{
  config = lib.mkIf cfg.enable {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
      substituters = [ "https://ikigai-desktop.cachix.org" ];
      trusted-public-keys = [ "ikigai-desktop.cachix.org-1:REPLACE_WITH_THE_KEY_FROM_APP_CACHIX_ORG" ];
    };
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    # Ten generations stay in the boot menu; rollback is picking one.
    boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;
  };
}

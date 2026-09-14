# The system half of the dev stack: what is a service, needs a group, or every user should
# have. The per-user tools are in the home module.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ikigai;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
      vim
      curl
      wget
      jq
      zip
      unzip
      openssh
      brightnessctl
      wl-clipboard
      grim
      slurp
      satty
      gpu-screen-recorder
      mpv
      ghostty
      zen
      zed
      zed-editor
      discord
      pear-desktop
      docker-compose
      lazydocker
      fzf
      ripgrep
      fd
    ];
  };
}

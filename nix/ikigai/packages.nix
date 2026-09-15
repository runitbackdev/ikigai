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
      # What Arch's base-devel gave: a crate's build.rs, a pip C extension, an npm native
      # module all expect cc, make and pkg-config on PATH, whatever toolchain mise fetched.
      gcc
      gnumake
      pkg-config
      binutils
      brightnessctl
      wl-clipboard
      grim
      slurp
      satty
      # The picker's Text action; English only, the full set is a gigabyte.
      (tesseract.override { enableLanguages = [ "eng" ]; })
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

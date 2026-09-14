# The Ikigai desktop as a NixOS module. A host imports this, sets `ikigai.enable` and
# `ikigai.user`, and gets what install.sh used to put on an Arch box: the compositor fork,
# the shell, the greeter, the dev stack, the theme and the system tuning. Every choice has
# an option; the personal flake (templates/personal) is where they are set.
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
  imports = [
    ./desktop.nix
    ./session.nix
    ./greeter.nix
    ./system.nix
    ./packages.nix
    ./gpu.nix
    ./steam.nix
    ./compat.nix
    ./nix.nix
  ];

  options.ikigai = {
    enable = lib.mkEnableOption "the Ikigai desktop";

    user = lib.mkOption {
      type = lib.types.str;
      example = "alice";
      description = ''
        The box's user. Created as a normal user in wheel, networkmanager, docker and video,
        with zsh as their shell and the Ikigai home module applied. Password, name and
        anything else about them go in `users.users.<name>` as usual.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "ikigai";
      description = "The theme under themes/ to build and apply, shell to cursors.";
    };

    themePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ikigai-theme.override { name = cfg.theme; };
      defaultText = lib.literalExpression "pkgs.ikigai-theme.override { name = config.ikigai.theme; }";
      description = "The built theme. Set `ikigai.theme` rather than this.";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [
        "none"
        "nvidia"
        "amd"
        "intel"
      ];
      default = "none";
      description = "The GPU vendor: picks the driver and, with Steam, its 32-bit half.";
    };

    nvidia.pin580 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Stay on the 580 branch with the proprietary modules: the 610.x open modules crash
        Proton games with Xid 109 (Arch bbs 313841). Off once a later branch is fixed.
      '';
    };

    wifiCountry = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "US";
      description = ''
        The wireless regulatory domain. Null derives it from `time.timeZone` through
        tzdata's zone.tab, so every channel and power level the country allows is
        available from boot instead of the kernel's world minimum.
      '';
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "Where the personal flake lives; what `ikigai-update` rebuilds from.";
    };

    steam.enable = lib.mkEnableOption "Steam, gamemode, gamescope, mangohud and the 32-bit driver";
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "docker"
      ]
      ++ lib.optional cfg.steam.enable "gamemode";
      shell = pkgs.zsh;
    };
    programs.zsh.enable = true;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "before-ikigai";
      users.${cfg.user} = {
        ikigai.enable = true;
      };
    };
  };
}

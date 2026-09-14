# The desktop: COSMIC's compositor (Ikigai's fork), Settings, Files and portal; the shell;
# the theme, icons, fonts and cursors; the config layers that make every app agree.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ikigai;
  commands = pkgs.ikigai-commands.override { flake = cfg.flake; };
  dconfSettings = {
    "org/gnome/desktop/interface" = {
      icon-theme = "Ikigai";
      cursor-theme = "Ikigai";
      cursor-size = lib.gvariant.mkInt32 24;
      gtk-theme = "adw-gtk3-dark";
      color-scheme = "prefer-dark";
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        cosmic-comp
        cosmic-bg
        cosmic-settings
        cosmic-settings-daemon
        cosmic-idle
        cosmic-randr
        cosmic-icons
        cosmic-sound-theme
        cosmic-files
        cosmic-viewer
        xwayland
        quickshell
        vicinae
        ikigai-shell
        ikigai-shell-plugins
        ikigai-session
        ikigai-icons
        ikigai-cosmic-config
        cfg.themePackage
        adw-gtk3
        playerctl
        xdg-user-dirs
        glib
      ]
      ++ lib.filter lib.isDerivation (lib.attrValues commands);

    # cosmic-config reads XDG_DATA_DIRS/cosmic; the greeter reads share/ikigai/theme and the
    # sessions; cosmic-bg reads share/backgrounds. The system profile merges every package's.
    environment.pathsToLink = [
      "/share/cosmic"
      "/share/backgrounds"
      "/share/ikigai"
      "/share/wayland-sessions"
    ];

    services.graphical-desktop.enable = true;
    services.displayManager.sessionPackages = [ pkgs.ikigai-session ];

    xdg = {
      sounds.enable = true;
      icons.fallbackCursorThemes = [ "Ikigai" ];
      portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-cosmic
          xdg-desktop-portal-gtk
        ];
        configPackages = [ pkgs.xdg-desktop-portal-cosmic ];
      };
    };

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      phosphor-font
    ];
    fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];

    # What COSMIC needs of the system, per nixpkgs' own cosmic module.
    environment.sessionVariables = {
      X11_BASE_RULES_XML = "${config.services.xserver.xkb.dir}/rules/base.xml";
      X11_EXTRA_RULES_XML = "${config.services.xserver.xkb.dir}/rules/base.extras.xml";
      XCURSOR_THEME = "Ikigai";
      XCURSOR_SIZE = "24";
    };
    security.polkit.enable = true;
    security.rtkit.enable = true;
    services.accounts-daemon.enable = true;
    services.libinput.enable = true;
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;
    services.gvfs.enable = true;
    services.geoclue2.enable = true;
    services.geoclue2.enableDemoAgent = false;
    services.geoclue2.whitelistedAgents = [ "geoclue-demo-agent" ];

    # Secrets: gnome-keyring, unlocked by the greeter's PAM stack (greeter.nix); the ssh
    # agent is gcr's, SSH_AUTH_SOCK set by ikigai-session.
    services.gnome.gnome-keyring.enable = true;
    services.gnome.gcr-ssh-agent.enable = true;
    programs.ssh.startAgent = false;

    # The icon theme reaches GTK apps through the settings portal, which serves gsettings,
    # so it is also a dconf default. The session runs with DCONF_PROFILE=cosmic, which has
    # to exist: the user's db, then these defaults, same as the stock profile.
    programs.dconf = {
      enable = true;
      profiles.user.databases = [ { settings = dconfSettings; } ];
      profiles.cosmic.databases = [ { settings = dconfSettings; } ];
    };

    # Middle-click autoscroll in Zen: Firefox's, off by default on Linux; a policy turns it
    # on as a default the user can still flip. Zen reads /etc/zen/policies instead of its
    # package's, so the trust-store policy the flake's package ships is repeated here.
    environment.etc."zen/policies/policies.json".text = builtins.toJSON {
      policies = {
        DisableAppUpdate = true;
        DefaultSerialGuardSetting = 3;
        Preferences."general.autoScroll" = {
          Value = true;
          Status = "default";
        };
        SecurityDevices."System Trust" = "${pkgs.p11-kit}/lib/pkcs11/p11-kit-trust.so";
      };
    };
  };
}

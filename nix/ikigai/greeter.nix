# The greeter: greetd runs `ikigai-greeter` (cosmic-comp in kiosk mode with the Quickshell
# greeter as its only client) as its own user. Its PAM stack unlocks gnome-keyring with the
# login password, so Zen, Zed, gh and the Chromium apps never ask twice.
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
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.ikigai-commands.ikigai-greeter}/bin/ikigai-greeter";
        user = "ikigai-greeter";
      };
    };
    # greetd exits when its greeter dies without starting a session, and NixOS restarts it
    # only after a clean exit: a greeter that failed at boot left a black screen until a
    # reboot. Restart it, a few times, and leave the journal to say why if it keeps dying.
    systemd.services.greetd = {
      serviceConfig = {
        Restart = lib.mkForce "always";
        RestartSec = "2s";
      };
      startLimitIntervalSec = 120;
      startLimitBurst = 10;
    };
    security.pam.services.greetd.enableGnomeKeyring = true;

    users.groups.ikigai-greeter = { };
    users.users.ikigai-greeter = {
      description = "Ikigai greeter";
      isSystemUser = true;
      group = "ikigai-greeter";
      extraGroups = [ "video" ];
      home = "/var/lib/ikigai-greeter";
      homeMode = "0750";
      createHome = true;
    };
    # Each user's shell leaves the name of their primary output here for the greeter's card.
    systemd.tmpfiles.rules = [ "d /var/lib/ikigai/greeter 1777 root root -" ];
  };
}

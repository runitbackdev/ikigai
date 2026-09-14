# The user; rename the file and every `alice` below. The Ikigai home module already holds
# every app config; this is what is only true here: who you are to git, how your home is
# laid out, what else you want installed. No password here: NixOS keeps it in /etc/shadow,
# `passwd` sets it, and the installer sets the first one for you.
{ pkgs, ... }:
{
  users.users.alice = {
    description = "alice";
  };

  home-manager.users.alice =
    { config, lib, ... }:
    {
      programs.git.settings.user = {
        name = "alice";
        email = "alice@example.com";
      };

      # A home layout, for instance PARA numbered 0 Areas, 1 Projects, 2 Resources, 3 Archive:
      # Documents and the file manager's projects entry point into it, the folders are made
      # at switch, nothing inside them is ever touched.
      # xdg.userDirs = {
      #   documents = "${config.home.homeDirectory}/PARA/2";
      #   extraConfig.XDG_PROJECTS_DIR = "${config.home.homeDirectory}/PARA/1";
      # };
      # home.activation.para = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #   run mkdir -p ~/PARA/0 ~/PARA/1 ~/PARA/2 ~/PARA/3
      # '';

      # Anything else: search.nixos.org has the names.
      home.packages = with pkgs; [
        # codex
      ];
    };
}

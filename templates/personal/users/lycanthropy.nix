# Me. The Ikigai home module already holds every app config; this is what is only true here:
# who I am to git, how my home is laid out, what else I want installed.
{ pkgs, ... }:
{
  users.users.lycanthropy = {
    description = "lycanthropy";
    # ikigai-install writes hashedPassword here; `mkpasswd` makes one by hand.
    initialPassword = "ikigai";
  };

  home-manager.users.lycanthropy =
    { config, lib, ... }:
    {
      programs.git = {
        userName = "lycanthropy";
        userEmail = "you@example.com";
      };

      # PARA: Projects, Areas, Resources, Archive. The XDG folders the file manager, the
      # file picker and the screenshot tool use point into it; the four are made at switch.
      xdg.userDirs = {
        documents = "${config.home.homeDirectory}/Resources";
        pictures = "${config.home.homeDirectory}/Resources/Pictures";
        videos = "${config.home.homeDirectory}/Resources/Videos";
        music = "${config.home.homeDirectory}/Resources/Music";
        download = "${config.home.homeDirectory}/Downloads";
        extraConfig.XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
      };
      home.activation.para = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ~/Projects ~/Areas ~/Resources ~/Archive
      '';

      home.packages = with pkgs; [
        # localsend
      ];
    };
}

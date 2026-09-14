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

      # PARA, numbered: 0 Areas, 1 Projects, 2 Resources, 3 Archive. Documents and the
      # file manager's projects entry point into it; Pictures, Videos, Music and Downloads
      # stay where they are (Pictures/Screenshots is where the shell puts screenshots).
      # The four are made at switch; nothing inside them is ever touched.
      xdg.userDirs = {
        documents = "${config.home.homeDirectory}/PARA/2";
        extraConfig.XDG_PROJECTS_DIR = "${config.home.homeDirectory}/PARA/1";
      };
      home.activation.para = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ~/PARA/0 ~/PARA/1 ~/PARA/2 ~/PARA/3
      '';

      home.packages = with pkgs; [
        # localsend
      ];
    };
}

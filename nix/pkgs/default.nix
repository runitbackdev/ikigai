# The overlay: Ikigai's own packages, the compositor fork in place of nixpkgs' cosmic-comp,
# and the names the rest of the tree uses (`zen`, `zed`) for packages nixpkgs names otherwise.
{ inputs }:
final: prev: {
  cosmic-comp = final.callPackage ./cosmic-comp.nix { cosmic-comp = prev.cosmic-comp; };

  # Chromium (Discord's streams) reads a decoded surface's dma-buf before the driver has
  # copied the frame into it, and the picture judders at a steady 60 fps. The patch's
  # header has the measurements.
  nvidia-vaapi-driver = prev.nvidia-vaapi-driver.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./nvidia-vaapi-driver-sync-held-exports.patch ];
  });

  ikigai-session = final.callPackage ./ikigai-session.nix { };
  ikigai-monitor = final.callPackage ./ikigai-monitor.nix { };
  ikigai-shell-plugins = final.callPackage ./ikigai-shell-plugins.nix { };
  ikigai-shell = final.callPackage ./ikigai-shell.nix { };
  ikigai-theme = final.callPackage ./ikigai-theme.nix { };
  ikigai-icons = final.callPackage ./ikigai-icons.nix { };
  ikigai-cosmic-config = final.callPackage ./cosmic-config.nix { };
  ikigai-commands = final.callPackage ./commands.nix { };
  phosphor-font = final.callPackage ./phosphor-font.nix { };

  zen = final.callPackage ./zen.nix {
    zen-beta = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.beta;
  };
  # nixpkgs ships Zed's binary as zeditor (zed is ZFS's event daemon). Zed's own installer,
  # the Super+E shortcut, EDITOR and every doc say zed; this makes that name true here too.
  zed = final.writeShellScriptBin "zed" ''exec ${final.zed-editor}/bin/zeditor "$@"'';
}

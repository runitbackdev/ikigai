# The driver for `ikigai.gpu`. NVIDIA uses production with open modules: latest (610.x) hangs
# Proton games with Xid 109 (docs/system.md). Sleep: the driver keeps video memory across
# suspend and its suspend, resume and hibernate services run, so the compositor comes back
# to a GPU that still has its state. Idle-suspend on AC stays off in the COSMIC config
# Ikigai ships until that has been seen to work.
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
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hardware.graphics.enable = true;
        hardware.graphics.enable32Bit = cfg.steam.enable;
      }
      (lib.mkIf (cfg.gpu == "nvidia") {
        services.xserver.videoDrivers = [ "nvidia" ];
        # The driver loads in the initrd, before any other GPU's can. The kernel numbers
        # connectors (DP-2) in the order the drivers register them, and on a box with an
        # iGPU as well that order is a race at boot: the same monitor was DP-2 one boot
        # and DP-5 the next, and everything keyed on the name (cosmic-comp's saved layouts,
        # its primary_output, shell.json's monitor) went to the wrong screen. Loaded first,
        # the card's connectors are always DP-1 up.
        boot.initrd.kernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_uvm"
          "nvidia_drm"
        ];
        hardware.nvidia = {
          modesetting.enable = true;
          open = true;
          package = config.boot.kernelPackages.nvidiaPackages.production;
          powerManagement.enable = true;
        };
      })
    ]
  );
}

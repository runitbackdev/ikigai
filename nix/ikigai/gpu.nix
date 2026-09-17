# The driver for `ikigai.gpu`. NVIDIA uses latest with open modules. Sleep: the driver keeps
# video memory across suspend and its suspend, resume and hibernate services run, so the
# compositor comes back to a GPU that still has its state. Idle-suspend on AC stays off in
# the COSMIC config Ikigai ships until that has been seen to work.
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
        hardware.nvidia = {
          modesetting.enable = true;
          open = true;
          package = config.boot.kernelPackages.nvidiaPackages.latest;
          powerManagement.enable = true;
        };
      })
    ]
  );
}

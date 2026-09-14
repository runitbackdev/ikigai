# The driver for `ikigai.gpu`. NVIDIA stays on the 580 branch with the proprietary modules
# while `ikigai.nvidia.pin580` holds (docs/system.md). Sleep is set up: the driver keeps
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
          open = !cfg.nvidia.pin580;
          package =
            if cfg.nvidia.pin580 then
              config.boot.kernelPackages.nvidiaPackages.legacy_580
            else
              config.boot.kernelPackages.nvidiaPackages.latest;
          powerManagement.enable = true;
        };
      })
    ]
  );
}

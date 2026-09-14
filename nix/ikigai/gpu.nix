# The driver for `ikigai.gpu`. NVIDIA stays on the 580 branch with the proprietary modules
# while `ikigai.nvidia.pin580` holds (docs/system.md). Idle-suspend on AC is off everywhere
# in the COSMIC config Ikigai ships, since resume on NVIDIA is not set up.
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
          powerManagement.enable = false;
        };
      })
    ]
  );
}

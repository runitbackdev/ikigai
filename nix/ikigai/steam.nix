# Steam on demand: `ikigai.steam.enable`, then `ikigai-steam` pins it to the rail and
# launches it. Proton comes with Steam; Proton-GE is offered next to it.
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
  config = lib.mkIf (cfg.enable && cfg.steam.enable) {
    # GE can use ntsync automatically, but it cannot load the kernel module itself.
    boot.kernelModules = [ "ntsync" ];
    # Some games need more mappings than the kernel's default allows. No RAM is reserved.
    boot.kernel.sysctl."vm.max_map_count" = 2147483642;

    programs.steam = {
      enable = true;
      package = pkgs.steam.override {
        extraEnv = {
          MANGOHUD = "1";
        }
        // lib.optionalAttrs (cfg.gpu == "nvidia") {
          # 10 GiB per driver cache; retain cleanup so caches remain bounded.
          __GL_SHADER_DISK_CACHE_SIZE = "10737418240";
        };
      };
      # Make the Vulkan overlay available inside Steam's FHS environment too.
      extraPackages = [ pkgs.mangohud ];
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      fontPackages = [ pkgs.liberation_ttf ];
    };
    # gamemode renices a game's threads to -10, the one weight scx_lavd reads, so a nice-0
    # build cannot preempt it. Its stock renice is 0. Split-lock throttling off while a
    # game runs: some Proton games take one every frame.
    programs.gamemode = {
      enable = true;
      enableRenice = true;
      settings.general = {
        renice = 10;
        softrealtime = "off";
        disable_splitlock = 1;
      };
    };
    environment.systemPackages = with pkgs; [
      gamescope
      mangohud
    ];
  };
}

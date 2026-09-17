# What Ikigai changes below the desktop (docs/system.md): memory, scheduler, boot and
# shutdown, firewall, networking, audio, and the small fixes.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ikigai;
  # The two-letter country of the timezone: "US" for America/New_York. zone.tab is tzdata's
  # table cut to country and zone, kept in the tree so evaluation needs no build.
  countryOfTimeZone =
    tz:
    let
      rows = lib.filter (l: l != "") (lib.splitString "\n" (builtins.readFile ./zone.tab));
      hit = lib.findFirst (l: builtins.elemAt (lib.splitString "\t" l) 1 == tz) null rows;
    in
    if hit == null then null else builtins.head (lib.splitString "\t" hit);
  country =
    if cfg.wifiCountry != null then
      cfg.wifiCountry
    else if config.time.timeZone != null then
      countryOfTimeZone config.time.timeZone
    else
      null;
in
{
  config = lib.mkIf cfg.enable {
    # Use a current kernel for sched_ext and ntsync support.
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    # zram the size of RAM, zstd, before any disk swap; the resident limit caps what the
    # compressed store may hold so incompressible data cannot eat the memory it relieves.
    services.zram-generator = {
      enable = true;
      settings.zram0 = {
        zram-size = "ram";
        zram-resident-limit = "ram / 3";
        compression-algorithm = "zstd";
        swap-priority = 100;
      };
    };
    # Swap is RAM, not a disk: compress a build's idle pages before dropping a game's
    # mapped files, and no readahead since every zram page is a decompress, not a seek.
    boot.kernel.sysctl = {
      "vm.swappiness" = 100;
      "vm.page-cluster" = 0;
    };

    # systemd-oomd kills the one runaway app when the apps' slice has sat under memory
    # pressure, or the cgroup using the most swap when zram is nearly full. The shell and
    # the compositor are outside app.slice and never candidates.
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
    };
    systemd.user.slices.app.sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };

    # sched_ext's LAVD instead of EEVDF: a 12-thread build no longer starves a game that
    # wakes and sleeps between frames. `scxctl stop` is EEVDF again, live.
    services.scx-loader = {
      enable = true;
      config = {
        default_sched = "scx_lavd";
        default_mode = "Auto";
      };
    };

    # A stuck service gets 5 s at shutdown, Docker 30 to stop its containers.
    systemd.settings.Manager.DefaultTimeoutStopSec = "5s";
    systemd.services."user@".serviceConfig.TimeoutStopSec = "5s";
    systemd.services.docker.serviceConfig.TimeoutStopSec = "30s";
    # The desktop never waits on DHCP.
    systemd.services.NetworkManager-wait-online.enable = false;

    networking.networkmanager.enable = true;
    # Deny incoming, allow outgoing; sshd opens its port itself when enabled. Docker's
    # published ports bypass this, as they did ufw.
    networking.firewall.enable = true;
    hardware.bluetooth.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    virtualisation.docker.enable = true;
    services.locate = {
      enable = true;
      package = pkgs.plocate;
    };
    services.fstrim.enable = true;

    # The fixes.
    programs.ssh.extraConfig = ''
      # Notice a dropped connection within a minute instead of sitting on a hung terminal.
      Host *
        ServerAliveInterval 15
        ServerAliveCountMax 3
        ConnectTimeout 10
    '';
    # Apple-style keyboards default to media keys on the F row; fnmode=2 makes them F-keys.
    boot.extraModprobeConfig = ''
      options hid_apple fnmode=2
    ''
    + lib.optionalString (country != null) ''
      options cfg80211 ieee80211_regdom=${country}
    '';
    hardware.wirelessRegulatoryDatabase = true;
  };
}

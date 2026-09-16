# Binaries from outside nixpkgs, which a developer box downloads all day: mise's toolchains,
# Zed's language servers, Claude Code's own installer. nix-ld gives them the loader and
# libraries they expect, envfs the /usr/bin shebangs.
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
  config = lib.mkIf cfg.enable {
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        zstd
        bzip2
        xz
        openssl
        curl
        expat
        libxml2
        icu
        glib
        gtk3
        gdk-pixbuf
        pango
        cairo
        fontconfig
        freetype
        harfbuzz
        dbus
        systemd
        libGL
        libdrm
        libgbm
        mesa
        vulkan-loader
        libxkbcommon
        wayland
        libx11
        libxext
        libxrender
        libxrandr
        libxi
        libxcursor
        libxfixes
        libxcomposite
        libxdamage
        libxtst
        libxcb
        libxkbfile
        alsa-lib
        pipewire
        libpulseaudio
        nss
        nspr
        at-spi2-core
        cups
        libsecret
        sqlite
        libuuid
        libnotify
        libusb1
        libffi
        ncurses
        readline
        gmp
      ];
    };
    services.envfs.enable = true;
  };
}

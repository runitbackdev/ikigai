# The live system the installer runs in, shared by the ISO (nix/iso.nix) and the kexec image
# (nix/kexec.nix): the installer on tty1, NetworkManager, the binary cache, the flake this
# was built from at /etc/ikigai.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  system.stateVersion = "25.11";
  # The installer profiles carry ZFS; no root pool to force-import here.
  boot.zfs.forceImportRoot = false;
  networking.networkmanager.enable = lib.mkForce true;
  networking.wireless.enable = lib.mkForce false;

  # The flake this image was built from: the template the installer writes, at the same
  # revision the install then fetches.
  environment.etc."ikigai".source = self;
  environment.systemPackages = with pkgs; [
    (pkgs.callPackage ./package.nix { })
    git
    jq
    curl
    gptfdisk
    parted
    efibootmgr
    mkpasswd
    dosfstools
    e2fsprogs
    util-linux
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://ikigai-desktop.cachix.org" ];
    trusted-public-keys = [ "ikigai-desktop.cachix.org-1:U+xIEO/ryk/+zJxA6nYXJTFdaT7uIu2VY3DkqhLX2B4=" ];
  };

  # Root logs in on tty1 and the installer runs; a second console stays plain.
  services.getty.autologinUser = lib.mkForce "root";
  programs.bash.interactiveShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ ! -e /run/ikigai-install-started ]; then
      touch /run/ikigai-install-started
      ikigai-install || echo "ikigai-install failed; run it again, or poke around"
    fi
  '';
}

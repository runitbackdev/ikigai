{
  lib,
  writeShellApplication,
  coreutils,
  util-linux,
  gptfdisk,
  dosfstools,
  e2fsprogs,
  efibootmgr,
  mkpasswd,
  curl,
  jq,
  git,
  gnused,
  gawk,
  gnugrep,
  networkmanager,
  nixos-install-tools,
  systemd,
}:
writeShellApplication {
  name = "ikigai-install";
  runtimeInputs = [
    coreutils
    util-linux
    gptfdisk
    dosfstools
    e2fsprogs
    efibootmgr
    mkpasswd
    curl
    jq
    git
    gnused
    gawk
    gnugrep
    networkmanager
    nixos-install-tools
    systemd
  ];
  text = builtins.readFile ./ikigai-install;
  meta.description = "The Ikigai installer, from the ISO: disk, user, timezone, then nixos-install";
}

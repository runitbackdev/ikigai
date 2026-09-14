# The ikigai-* commands (bin/), each a package: store paths substituted for the @names@ in
# the scripts, shellcheck run at build, and each command's tools on its PATH. The module
# installs all of them; the greeter unit names one.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  shellcheck,
  python3,
  coreutils,
  util-linux,
  procps,
  gnugrep,
  gnused,
  gawk,
  perl,
  fzf,
  jq,
  git,
  glib,
  systemd,
  quickshell,
  cosmic-comp,
  grim,
  slurp,
  wl-clipboard,
  xdg-user-dirs,
  gpu-screen-recorder,
  networkmanager,
  docker,
  gnutar,
  gzip,
  nix,
  nixos-rebuild-ng,
  ikigai-shell,
  ikigai-shell-plugins,
  flake ? "/etc/nixos",
}:
let
  mkCommand =
    name:
    {
      runtimeInputs ? [ ],
      substitutions ? { },
      python ? false,
    }:
    stdenvNoCC.mkDerivation {
      inherit name;
      version = "0.1.0";
      src = ../../bin + "/${name}";
      dontUnpack = true;
          nativeBuildInputs = [ makeWrapper ] ++ (if python then [ pythonEnv ] else [ shellcheck ]);
      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        substitute $src $out/bin/${name} ${
          lib.concatStringsSep " " (
            lib.mapAttrsToList (k: v: "--subst-var-by ${k} ${lib.escapeShellArg (toString v)}") substitutions
          )
        }
        chmod +x $out/bin/${name}
        patchShebangs $out/bin/${name}
        ${lib.optionalString (!python) "shellcheck -S warning $out/bin/${name}"}
        ${lib.optionalString (runtimeInputs != [ ])
          "wrapProgram $out/bin/${name} --prefix PATH : ${lib.makeBinPath runtimeInputs}"
        }
        runHook postInstall
      '';
      meta.mainProgram = name;
    };
  shell = "${ikigai-shell}/share/ikigai/shell";
  # ikigai-caffeinate holds its inhibit through GLib's D-Bus bindings.
  pythonEnv = python3.withPackages (p: [ p.pygobject3 ]);
in
{
  ikigai-caffeinate = mkCommand "ikigai-caffeinate" {
    python = true;
    runtimeInputs = [ glib ];
  };
  ikigai-doctor = mkCommand "ikigai-doctor" {
    runtimeInputs = [
      coreutils
      util-linux
      gnugrep
      gnused
      gawk
      jq
      git
      systemd
      quickshell
    ];
    substitutions = { inherit shell flake; };
  };
  ikigai-greeter = mkCommand "ikigai-greeter" {
    runtimeInputs = [
      cosmic-comp
      quickshell
      systemd
    ];
    substitutions = {
      inherit shell;
      qml = "${ikigai-shell-plugins}/lib/qt6/qml";
    };
  };
  ikigai-keys = mkCommand "ikigai-keys" {
    runtimeInputs = [
      coreutils
      perl
      gawk
      gnused
      fzf
    ];
  };
  ikigai-migrate = mkCommand "ikigai-migrate" {
    runtimeInputs = [
      coreutils
      util-linux
      gnugrep
      gnused
      gawk
      gnutar
      gzip
      jq
      networkmanager
      docker
      systemd
    ];
  };
  ikigai-shell = mkCommand "ikigai-shell" {
    runtimeInputs = [
      coreutils
      quickshell
    ];
    substitutions = { inherit shell; };
  };
  ikigai-shot = mkCommand "ikigai-shot" {
    runtimeInputs = [
      coreutils
      procps
      gnugrep
      jq
      quickshell
      grim
      slurp
      wl-clipboard
      xdg-user-dirs
      gpu-screen-recorder
    ];
    substitutions = { inherit shell; };
  };
  ikigai-steam = mkCommand "ikigai-steam" {
    runtimeInputs = [
      coreutils
      util-linux
      gnugrep
      jq
    ];
  };
  ikigai-update = mkCommand "ikigai-update" {
    runtimeInputs = [
      coreutils
      git
      nix
      nixos-rebuild-ng
      systemd
    ];
    substitutions = { inherit flake; };
  };
}

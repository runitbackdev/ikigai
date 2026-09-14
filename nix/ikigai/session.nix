# The session: `ikigai-session` starts cosmic-comp, imports its environment into the user
# manager and starts ikigai-session.target, which pulls the units below (docs/architecture.md).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ikigai;
  qmlImportPath = "${pkgs.ikigai-shell-plugins}/lib/qt6/qml";
  unit = description: exec: {
    inherit description;
    partOf = [ "ikigai-session.target" ];
    after = [ "graphical-session-pre.target" ];
    serviceConfig = {
      ExecStart = exec;
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.targets.ikigai-session = {
      description = "Ikigai session";
      wants = [
        "ikigai-bridge.service"
        "ikigai-outputs.service"
        "ikigai-bg.service"
        "ikigai-shell.service"
        "ikigai-settings-daemon.service"
        "ikigai-idle.service"
        "graphical-session-pre.target"
        "xdg-desktop-autostart.target"
      ];
      bindsTo = [ "graphical-session.target" ];
      before = [
        "graphical-session.target"
        "xdg-desktop-autostart.target"
      ];
      after = [ "graphical-session-pre.target" ];
    };

    systemd.user.services = {
      ikigai-bg = unit "Ikigai wallpaper (cosmic-bg)" "${pkgs.cosmic-bg}/bin/cosmic-bg";
      ikigai-bridge = unit "Ikigai bridge (COSMIC toplevels and workspaces over a unix socket)" "${pkgs.ikigai-session}/bin/ikigai-bridge";
      ikigai-idle = unit "Ikigai idle watcher (cosmic-idle)" "${pkgs.cosmic-idle}/bin/cosmic-idle";
      ikigai-outputs = unit "Ikigai outputs (keeps the display layout across the monitors' sleep)" "${pkgs.ikigai-session}/bin/ikigai-outputs";
      ikigai-settings-daemon = unit "Ikigai settings daemon (cosmic-settings-daemon)" "${pkgs.cosmic-settings-daemon}/bin/cosmic-settings-daemon";
      ikigai-shell =
        unit "Ikigai shell (Quickshell)" "${pkgs.quickshell}/bin/qs -p ${pkgs.ikigai-shell}/share/ikigai/shell/shell.qml"
        // {
          environment = {
            QT_QPA_PLATFORM = "wayland";
            QT_QPA_PLATFORMTHEME = "";
            QS_DISABLE_FILE_WATCHER = "1";
            QML_IMPORT_PATH = qmlImportPath;
          };
        };
      # Vicinae disables layer-shell when XDG_CURRENT_DESKTOP contains "cosmic"
      # (cosmic-comp#1590); the forked compositor fixes that bug, so this process gets a
      # different desktop name. Wanted by graphical-session.target the way its own unit is
      # installed; a Wants= from ikigai-session.target would form an ordering cycle.
      vicinae = {
        description = "Vicinae launcher";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        environment = {
          XDG_CURRENT_DESKTOP = "Ikigai";
          QT_QPA_PLATFORM = "wayland";
          QT_QPA_PLATFORMTHEME = "";
        };
        serviceConfig = {
          ExecStart = "${pkgs.vicinae}/bin/vicinae server";
          Restart = "on-failure";
          RestartSec = 1;
        };
      };
    };
  };
}

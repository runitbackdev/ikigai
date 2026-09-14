# The Quickshell shell (shell/), greeter and lock included, as share/ikigai/shell. Its two
# fixed paths become the system profile's, which every theme and session package feeds.
{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "ikigai-shell";
  version = "0.1.0";
  src = lib.cleanSourceWith {
    src = ../../shell;
    filter = path: type: !(lib.hasInfix "/plugin" path);
  };

  postPatch = ''
    substituteInPlace Lock.qml greeter.qml \
      --replace-fail 'file:///usr/local/share/ikigai/theme/wallpaper.jpg' \
        'file:///run/current-system/sw/share/ikigai/theme/wallpaper.jpg'
    substituteInPlace Users.qml \
      --replace-fail '/usr/share/wayland-sessions/*.desktop' \
        '/run/current-system/sw/share/wayland-sessions/*.desktop'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/ikigai/shell
    cp -r . $out/share/ikigai/shell/
    runHook postInstall
  '';

  meta = {
    description = "The Ikigai shell: rail, cards, launcher, notifications, greeter, lock";
    license = lib.licenses.gpl3Only;
  };
}

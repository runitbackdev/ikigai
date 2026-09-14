# The two QML modules the shell needs C++ for (shell/plugin): Ikigai.Blobs, the renderer
# vendored from caelestia-shell, and Ikigai.Input. Installed under lib/qt6/qml; the shell
# and greeter units put that on QML_IMPORT_PATH.
{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  qt6,
  wayland,
  libxkbcommon,
}:
stdenv.mkDerivation {
  pname = "ikigai-shell-plugins";
  version = "0.1.0";
  src = lib.cleanSource ../../shell/plugin;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.qtshadertools
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtshadertools
    wayland
    libxkbcommon
  ];
  cmakeFlags = [ (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib") ];
  # Plugins, not apps: nothing to wrap.
  dontWrapQtApps = true;

  meta = {
    description = "Ikigai's QML plugins: the blob renderer and keyboard state";
    license = lib.licenses.gpl3Only;
  };
}

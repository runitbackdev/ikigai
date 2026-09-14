# A theme (themes/<name>), put where each consumer reads it:
#   share/ikigai/theme/{shell.json,wallpaper.jpg}   the greeter and lock, under one fixed path
#   share/ikigai/themes/<name>/                     the per-app files the home module installs
#   share/backgrounds/ikigai/<name>.jpg             what CosmicBackground points at
#   share/cosmic/                                   the COSMIC theme, system layer
#   share/icons/Ikigai/                             the cursors: SVGs for cosmic-comp, Xcursor for the rest
# `ikigai.theme` in the NixOS module picks the name; `override { name = ...; }` builds another.
{
  lib,
  stdenvNoCC,
  python3,
  librsvg,
  xcursorgen,
  name ? "ikigai",
}:
stdenvNoCC.mkDerivation {
  pname = "ikigai-theme-${name}";
  version = "0.1.0";
  src = ../../themes + "/${name}";
  cursorRaster = ../../scripts/cursor-raster.py;

  nativeBuildInputs = [
    python3
    librsvg
    xcursorgen
  ];

  installPhase = ''
    runHook preInstall
    t=$out/share/ikigai/themes/${name}
    mkdir -p $out/share/ikigai/theme $t $out/share/backgrounds/ikigai $out/share/cosmic $out/share/icons

    install -m644 shell.json $out/share/ikigai/theme/shell.json
    install -m644 wallpaper.jpg $out/share/ikigai/theme/wallpaper.jpg
    install -m644 wallpaper.jpg $out/share/backgrounds/ikigai/${name}.jpg
    install -m644 palette.json shell.json $t/
    for d in ghostty btop vicinae gtk; do [ -d $d ] && cp -r $d $t/; done

    # The COSMIC theme files: everything but the builder's input and its note. The wallpaper
    # path in CosmicBackground is this package's.
    (cd cosmic && find . -type f -not -name '*.ron' -not -name README) | while read -r f; do
      install -Dm644 "cosmic/$f" "$out/share/cosmic/$f"
    done
    substituteInPlace $out/share/cosmic/com.system76.CosmicBackground/v1/all \
      --replace-fail '/usr/local/share/backgrounds/ikigai/${name}.jpg' "$out/share/backgrounds/ikigai/${name}.jpg"

    python3 $cursorRaster cursors/Ikigai $out/share/icons/Ikigai
    runHook postInstall
  '';

  meta = {
    description = "The ${name} theme for Ikigai";
    license = with lib.licenses; [ mit gpl3Only ];
  };
}

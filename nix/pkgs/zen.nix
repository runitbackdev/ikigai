# Zen under the name Arch's package gave it: the binary, the desktop entry and the app id
# are `zen`, which is what the rail's pins, mimeapps and the shortcuts say. The flake's
# package calls all three zen-beta; MOZ_APP_LAUNCHER is what its wrapper reads for the name.
{
  lib,
  stdenvNoCC,
  zen-beta,
}:
stdenvNoCC.mkDerivation {
  pname = "zen";
  inherit (zen-beta) version;
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications
    cat > $out/bin/zen <<SH
    #!/bin/sh
    MOZ_APP_LAUNCHER=zen exec ${zen-beta}/bin/zen-beta "\$@"
    SH
    chmod +x $out/bin/zen
    sed -e 's/zen-beta/zen/g' -e 's/^Name=Zen Browser (Beta)/Name=Zen/' \
      ${zen-beta}/share/applications/zen-beta.desktop > $out/share/applications/zen.desktop
    ln -s ${zen-beta}/share/icons $out/share/icons
    runHook postInstall
  '';
  passthru.unwrapped = zen-beta;
  meta = zen-beta.meta // {
    mainProgram = "zen";
  };
}

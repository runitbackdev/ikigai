# Phosphor's icon font, every weight. The shell's glyph table (shell/Icons.qml) is generated
# from the same release by scripts/vendor-phosphor.sh; keep the two at one version.
{ lib, stdenvNoCC, fetchgit }:
stdenvNoCC.mkDerivation {
  pname = "phosphor-font";
  version = "2.1.2";
  src = fetchgit {
    url = "https://github.com/phosphor-icons/web";
    rev = "70854726d7bd82ae21f0dc81b5b5c35240a77066";
    hash = "sha256-j3TIuzkwnrKmyhxK6KsiOC9lagjaVULC465P8b7favc=";
  };
  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/fonts/truetype src/*/Phosphor*.ttf
    runHook postInstall
  '';
  meta = {
    description = "Phosphor icons as a font";
    homepage = "https://phosphoricons.com";
    license = lib.licenses.mit;
  };
}

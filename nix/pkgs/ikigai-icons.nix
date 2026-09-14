# The Ikigai icon theme: Phosphor's SVGs as a symbolic icon theme (icons/Ikigai, built by
# scripts/vendor-icon-theme.sh). Cursors of the same name come from ikigai-theme; the
# system profile merges the two directories.
{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "ikigai-icons";
  version = "0.1.0";
  src = ../../icons/Ikigai;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons/Ikigai
    cp -r . $out/share/icons/Ikigai/
    runHook postInstall
  '';
  meta = {
    description = "The Ikigai icon theme, from Phosphor";
    license = lib.licenses.mit;
  };
}

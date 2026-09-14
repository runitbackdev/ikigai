# ikigai-monitor (monitor/): the task manager's data, Mission Center's Magpie daemon
# spoken to directly and re-emitted as JSON lines. The shell runs it while the card is
# open; the daemon is nixpkgs' mission-center's, so its fixes arrive with nixpkgs.
{
  lib,
  rustPlatform,
  mission-center,
}:
rustPlatform.buildRustPackage {
  pname = "ikigai-monitor";
  version = "0.1.0";
  src = lib.cleanSource ../../monitor;
  cargoHash = "sha256-1uxnuW+Zh/TTWBZx/aAbA/qSHat64N2BKMp3LCQt9a4=";

  postPatch = ''
    substituteInPlace src/main.rs \
      --replace-fail 'const MAGPIE: &str = "missioncenter-magpie";' \
        'const MAGPIE: &str = "${mission-center}/bin/missioncenter-magpie";'
  '';

  meta = {
    description = "The Ikigai task manager's data: Magpie's readings as JSON lines";
    license = lib.licenses.gpl3Plus;
    mainProgram = "ikigai-monitor";
  };
}

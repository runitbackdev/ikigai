# ikigai-session, ikigai-bridge and ikigai-outputs (session/), and the session entry the
# greeter offers. Their units are in nix/ikigai/session.nix, where the other packages'
# store paths are known.
{
  lib,
  rustPlatform,
  pkg-config,
  libxkbcommon,
}:
rustPlatform.buildRustPackage {
  pname = "ikigai-session";
  version = "0.1.0";
  src = lib.cleanSource ../../session;
  cargoHash = "sha256-i9XeJQCyHdHjG4reKYgfeYpN9Ivfe+4X4iwEGZExPGI=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libxkbcommon ];

  postPatch = ''
    # The cursors are in the system profile's icon dir, which no toolkit searches on its own.
    substituteInPlace src/bin/ikigai-session.rs \
      --replace-fail '/usr/local/share/icons:~/.local/share/icons:~/.icons:/usr/share/icons:/usr/share/pixmaps' \
        '/run/current-system/sw/share/icons:~/.local/share/icons:~/.icons'
  '';

  # The only session entry. DesktopNames is COSMIC so cosmic-settings' entries show.
  postInstall = ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/ikigai.desktop <<EOF
    [Desktop Entry]
    Name=Ikigai
    Comment=cosmic-comp with the Ikigai shell
    Exec=$out/bin/ikigai-session
    Type=Application
    DesktopNames=COSMIC
    EOF
  '';

  passthru.providedSessions = [ "ikigai" ];

  meta = {
    description = "The Ikigai session launcher, bridge and output manager";
    license = lib.licenses.mit;
    mainProgram = "ikigai-session";
  };
}

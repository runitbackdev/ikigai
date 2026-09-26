# The system layer of desktop config: COSMIC's defaults under share/cosmic (cosmic-config
# reads the first data dir that has a config's directory, and the system profile merges this
# with cosmic-settings' own `defaults`), the desktop entries Ikigai rewrites, and the default
# apps at the lowest XDG layer. hiPrio so a collision with a stock file resolves to ours.
{
  lib,
  runCommand,
  cosmic-settings,
  discord,
  pear-desktop,
  # Discord decodes its streams in software; desktop.nix sets this on NVIDIA. There
  # Chromium reads a decoded VA surface's dma-buf right after vaEndPicture with no sync,
  # nvidia-vaapi-driver copies the frame in afterwards, and the stream judders at a steady
  # 60 fps (8 vaSyncSurface calls for 2280 pictures, Electron 42). A driver patch that
  # resolved the picture before vaEndPicture returned was carried until 2026-09-26;
  # elFarto's answer on the issue was to keep the driver out of it, so
  # LIBVA_DRIVER_NAME=none leaves Chromium to dav1d.
  discordSoftwareDecode ? false,
}:
lib.hiPrio (
  runCommand "ikigai-cosmic-config" { } ''
    mkdir -p $out/share/cosmic $out/share/applications
    cp -r ${../../config/cosmic}/. $out/share/cosmic/
    chmod -R u+w $out/share/cosmic

    # Vicinae runs as XDG_CURRENT_DESKTOP=Ikigai, so Settings' OnlyShowIn=COSMIC would hide
    # it from the launcher. Same entry, one line fewer.
    sed '/^OnlyShowIn=/d' ${cosmic-settings}/share/applications/com.system76.CosmicSettings.desktop \
      > $out/share/applications/com.system76.CosmicSettings.desktop

    # Discord and YouTube Music are Chromium, which picks its password store from the
    # desktop's name and knows no COSMIC: name the keyring outright or tokens land in a
    # plaintext store. (Middle-click autoscroll is the compositor's now, not a blink flag.)
    for entry in ${discord}/share/applications/discord.desktop ${pear-desktop}/share/applications/*.desktop; do
      sed 's|^Exec=\([^ ]*\)|Exec=\1 --password-store=gnome-libsecret|' \
        "$entry" > "$out/share/applications/$(basename "$entry")"
    done
    ${lib.optionalString discordSoftwareDecode ''
      sed -i 's|^Exec=|Exec=env LIBVA_DRIVER_NAME=none |' $out/share/applications/discord.desktop
    ''}

    install -m644 ${../../config/applications/mimeapps.list} $out/share/applications/mimeapps.list
    # The task manager, for Vicinae: the card, not a window.
    install -m644 ${../../config/applications/ikigai-monitor.desktop} $out/share/applications/ikigai-monitor.desktop
  ''
)

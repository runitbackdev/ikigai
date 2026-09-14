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

    # Discord and YouTube Music are Chromium, whose middle-click autoscroll is behind a blink
    # flag, and which picks its password store from the desktop's name and knows no COSMIC:
    # name the keyring outright or tokens land in a plaintext store.
    for entry in ${discord}/share/applications/discord.desktop ${pear-desktop}/share/applications/*.desktop; do
      sed 's|^Exec=\([^ ]*\)|Exec=\1 --enable-blink-features=MiddleClickAutoscroll --password-store=gnome-libsecret|' \
        "$entry" > "$out/share/applications/$(basename "$entry")"
    done

    install -m644 ${../../config/applications/mimeapps.list} $out/share/applications/mimeapps.list
    # The task manager, for Vicinae: the card, not a window.
    install -m644 ${../../config/applications/ikigai-monitor.desktop} $out/share/applications/ikigai-monitor.desktop
  ''
)

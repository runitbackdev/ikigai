# Ikigai v2 plan

## NixOS, 2026-09-14

Ikigai moves from Arch to NixOS; the Arch path (`boot.sh`, `archinstall.json`, `install/`,
the pacman repo) is retired. The desktop is a NixOS module (`nix/ikigai`), every app config
is a full Home Manager module (`nix/home`), the compositor fork is an overlay over nixpkgs'
cosmic-comp built into the `ikigai-desktop` Cachix cache. A box is a separate personal
flake (`templates/personal`) that `ikigai-install` writes to `/etc/nixos`; `ikigai-migrate`
carries the rest of an Arch box over. Left to verify on hardware: the ISO and `boot.ps1`
boot, the installer's two modes, the greeter and session under the fork, NVIDIA's 580
pin, `nix run .#vm`, and the cache once its key is pasted in. Everything below is history.

Decided 2026-09-02. Ikigai keeps cosmic-comp (window chrome, floating-first with a tiling
toggle) and the COSMIC portal, and replaces the rest of the COSMIC session with its own
launcher and a Quickshell shell. Nothing ships until the swap (step G); until then "Ikigai"
is an experimental greeter entry next to stock COSMIC.

## Already done

- `session/`: `ikigai-session` (cosmic-comp handshake, `ikigai-session.target`) and
  `ikigai-bridge` (COSMIC toplevel + workspace protocols → `$XDG_RUNTIME_DIR/ikigai-bridge.sock`,
  JSON lines). Units under `/usr/local/lib/systemd/user`, built at install (`rust`, ~30 s).
- `ikigai-bg.service` runs cosmic-bg under the target: it reads the `CosmicBackground`
  config Ikigai already ships, keeps the Settings wallpaper page working, and is a leaf.

## Fixed decisions

| Area | Decision |
|---|---|
| First swap milestone | Shell v0 = taskbar + launcher + notifications + tray/volume/clock. OSD included (small once volume exists). Idle/lock and greeter after. |
| Shell files | Ikigai-owned: `shell/` in the repo → `/usr/local/share/ikigai/shell/`, run by `ikigai-shell.service` (`qs -p …/shell.qml`). Users don't edit QML. |
| Bar | caelestia-shell's look, on its vendored blob renderer (`shell/plugin`, GPL-3): a rounded 10 px frame around the desktop, a thin (40 px) autohiding rail that grows out of the frame's left border, cards that melt out of the rail. One full-screen layer per screen plus four 1 px exclusion windows, always mapped (autohide is a resize). Overlays (switcher, screenshot picker) are `LazyLoader`s: map on demand, unmap on close; safe since the Qt patch (cosmic-comp#1590), and how an Overlay layer gets keyboard focus at all (granted at map only). Pinned + running apps at the top, clock stacked at the bottom. |
| Launcher | Vicinae (`vicinae-bin`), upstream's `vicinae.service` enabled into `graphical-session.target` plus a drop-in that sets `XDG_CURRENT_DESKTOP=Ikigai` (Vicinae refuses layer-shell on "cosmic", and its 0.28.1 config says so outright; the patched Qt makes it safe). Super, Super+A, the start button and the search icon run `vicinae toggle`. Palette-only theming via a generated `ikigai.toml`, telemetry off, welcome tour kept. Replaces cosmic-launcher and app-library. Gotcha found at the swap (e447455): cosmic-settings' entries are `OnlyShowIn=COSMIC`, so the rename hid Settings; `install/configs.sh` installs a copy minus that line under `/usr/local/share/applications`. Its power commands (`vicinae cmd launch power:logout|power-off|reboot|sleep|lock`) run without confirmation and are the LogOut/PowerOff path. |
| Notifications | Done 2026-09-04 (781e657, next commit). `Notifs` singleton owns Quickshell's NotificationServer. Toasts = one sheet at the top right drawn by Bar as a blob out of the top border (`Toasts`/`Toast`: app timeout or 5 s, none for critical, paused under the pointer, fade then expire/dismiss, default action on click, middle-click dismisses). `Sidebar` (clock click, `ikigai-shell sidebar toggle`) hangs out of the right border: history (session-only, 50), bell = do-not-disturb (`dnd` in shell.json), broom clears, `Calendar` month view; the bar masks the whole screen while open so an outside click closes it; clock badge = unread. One screen only: toasts land on `monitor` in shell.json (else the first), the sidebar opens on the rail whose clock was clicked (`ikigai-shell sidebar toggle` uses the same monitor). Replaces cosmic-notifications. Open: apps without a desktop-entry hint get the generic icon. |
| Status items v0 | Done 2026-09-04 (95a5023, next commit). `Status` above the clock: tray (`TrayButton`/`TrayMenu`, Quickshell SystemTray joining Vicinae's watcher) and a volume glyph (`Audio` singleton over PipeWire: scroll steps, click → `VolumeCard` popout). OSD (`Osd` singleton + `OsdPill`, a pill out of the bottom border) shows on any sink level/mute or mic mute change, so `system_actions` VolumeRaise/Lower are plain `wpctl` calls; BrightnessUp/Down → `ikigai-shell osd brightness up\|down` (brightnessctl, in PACMAN; untested: no backlight on the VM). Tray submenus not rendered. Network and battery after the swap. |
| Theme | `themes/<name>/palette.json` (M3 tokens + ANSI 16, generated by `scripts/theme-palette.py`) is the source; `scripts/theme-build.py` renders shell.json, the COSMIC builder, Ghostty, btop, Vicinae, gtk.css and the cursor theme (Bibata Modern's SVGs from `cursors/bibata`, recoloured; done 2026-09-06) from it. `ikigai-theme-set` installs them, rasterising the cursors into Xcursor files on the way; the QML watches `~/.local/state/ikigai/shell-theme.json`. Greeter and lock reuse it. |
| Switcher | Alt+Tab / Alt+Shift+Tab bound through `system_actions` to `ikigai-shell switcher next|prev` (a `qs ipc` wrapper). `shell/Switcher.qml` maps an Overlay layer with exclusive keyboard focus, so the Alt release lands on it; the list is frozen at open in the bridge's `last_active` order; it drops the keyboard claim, then activates 50 ms later (cosmic-comp re-validates focus against exclusive layers). Previews: the bridge captures each listed window once (`capture` request → `thumbnail` event, PPM under `$XDG_RUNTIME_DIR/ikigai/thumbs`). |
| User config | `~/.config/ikigai/shell.json`, seeded once: pinned apps (Ghostty, Zen, Zed, Settings), autohide, bar scale. Pin/unpin from the taskbar context menu writes it back. |
| Daemons kept under the target | Done 2026-09-04: `ikigai-settings-daemon.service` and `ikigai-idle.service` wanted by the target. The settings daemon logs "Failed to sync with greeter" (it writes for cosmic-greeter; ours reads nothing there) and stays for brightness-by-Settings, sounds, geoclue theme switching, input sources. cosmic-idle serves org.freedesktop.ScreenSaver and locks via `loginctl lock-session`. cosmic-osd replaced: OSD by Status items, its polkit agent by the Polkit row, its log-out/shutdown dialogs by Vicinae's commands (LogOut/PowerOff unbound, 6bba107). |
| Polkit | Done 2026-09-04 (3c3fa57). cosmic-osd was COSMIC's authentication agent (its binary registers `org.freedesktop.PolicyKit1.AuthenticationAgent`); the Ikigai session never ran it, so privilege prompts failed silently before the swap too. `shell/Polkit.qml`: Quickshell 0.3.1's `PolkitAgent`/`AuthFlow` on `AuthCard` (new `subtitle` line for the request message), Overlay layer with exclusive focus on the first screen, Escape or a scrim click cancels, a failed try shakes and re-asks. The card names `flow.selectedIdentity.displayName` (polkit's pick, the wheel user here, not root) and looks it up in `Accounts` for the avatar. Verified: `pkexec` from a session terminal, wrong password, cancel. Not verified: success (needs the VM user's password). Not done: identity chooser when polkit offers several. Test gotcha: `pkexec` over ssh is not in the seat0 session and finds no agent. |
| Settings app | cosmic-settings stays; its Panel/Dock pages render empty with "Reset to default" (verified, no crash) and the README says so. Reachable from Vicinae after the OnlyShowIn override (Launcher row). The rail's own settings (autohide, scale, icon overrides) have no UI: a settings card in the shell, after G. |
| First login | Done 2026-09-05 (643479b): `shell/Welcome.qml`, a card in Polkit's shape (Overlay layer, scrim, first screen) 1.5 s after the shell starts while `~/.local/state/ikigai/welcomed` is missing; Got it, Escape or a scrim click writes the marker. `ikigai-shell welcome open` reopens it (not `show`: `qs ipc call x show` falls through to the CLI's `show` subcommand). Offline per `nmcli -g CONNECTIVITY general` → a Connect to Wi-Fi pill runs `cosmic-settings wireless` via `Apps.spawn`; the rail's network item replaces it later. cosmic-initial-setup is dropped at the swap; locale/keyboard come from archinstall or the existing system. |
| Battery | Done 2026-09-05 (2c19e72, 21b88cb): `upower` + `power-profiles-daemon` in the package list (both D-Bus activated, no enable). `shell/Power.qml` wraps Quickshell's `UPower.displayDevice` and `PowerProfiles` like Audio wraps PipeWire; `Status.qml` shows the button only when a battery is present; `BatteryCard.qml` has the level bar, the status line with time left, and the profile cells (Performance only where the daemon offers it). Verified with a forced device on the VM; the profile click reached the daemon. |
| Network | Done 2026-09-05 (c9d9935, 3565567). `shell/Network.qml`: nmcli behind a singleton, `nmcli monitor` as the change feed, terse multiline output parsed on the first colon. Connect paths: saved → `connection up`; open → `device wifi connect`; new secured → profile without a key and `autoconnect no`, password in `$XDG_RUNTIME_DIR/ikigai-psk`, `connection up ... passwd-file`, then `autoconnect yes`. Wrong key = third "need authentication" line (nmcli re-feeds the file on every retry; the 30 s `-w` is the backstop); a failed fresh profile is deleted. `NetworkCard.qml` on the rail; `WifiAuth.qml` is the password window (Overlay + exclusive focus, the popout has none); the welcome card's Wi-Fi pill opens the rail card via `Network.cardRequested`. Verified on the VM with `mac80211_hwsim` (3 radios, hostapd WPA2 + open, dnsmasq, `ufw allow in on wlan0`): open and secured connect, wrong password, forget, disconnect, radio off and on with autoconnect. Not a D-Bus backend: same information, a fraction of the code; the singleton is the seam. Gotchas: `nmcli --ask` re-prompts forever on a piped stdin; NetworkManager refuses an ssh session (not seat-active) so test from the session; a fresh profile autoconnects keyless at once. |
| Greeter | Built 2026-09-04 (commits caf8987, 6055f48), ahead of D–G. greetd (`greeter/ikigai-greeter.toml`, unit aliasing display-manager.service) runs `bin/ikigai-greeter` as the `ikigai-greeter` user: `cosmic-comp --no-xwayland qs -p shell/greeter.qml` (kiosk mode: comp exits with its client, greetd then starts the session). No daemon: theme + wallpaper from `/usr/local/share/ikigai/theme` (written by theme-set, `IKIGAI_THEME_FILE`), users from `/etc/passwd` in login.defs's UID range, avatars from `/var/lib/AccountsService/icons` (world-readable, cosmic-settings writes them), sessions parsed from `/usr/share/wayland-sessions` so both are offered until the swap, last choice in the greeter's home. Gaps: keyboard layout is the compositor default (seed from archinstall's choice later); no caps-lock hint; verified under llvmpipe only. cosmic-greeter dropped at the swap; the pills vanish with `cosmic.desktop` (verified). `install/greeter.sh` disables whichever unit holds the display-manager alias, not just cosmic-greeter (8947a11). |
| Lock | Done 2026-09-04: `shell/Lock.qml` (`WlSessionLock` + `PamContext` config "login") on `AuthCard`, the greeter's card. Triggers all go through logind: `ikigai-session` runs `gdbus monitor --system --dest org.freedesktop.login1` and relays Lock/Unlock for its own session path and PrepareForSleep(true) as `ikigai-shell session lock\|unlock`. Gotcha: cosmic-comp only focuses a lock surface during a focus fixup, never on an empty desktop → Lock maps a 1 px exclusive layer ("bait") before locking and unmaps it after. Not done: SetLockedHint to logind. 2026-09-06: the card, the bait, polkit, welcome, Wi-Fi auth and the switcher all sit on `Screens.primary` (`monitor` in shell.json, else the first screen); the greeter has no shell.json and keeps the first. |
| Displays | Done 2026-09-07: `session/src/bin/ikigai-outputs.rs` + `ikigai-outputs.service`. From the journal: on DPMS wake the NVIDIA driver (610.57 open) rejects cosmic-comp 1.7.0's first page flip (EINVAL on card2), so `Config::read_outputs` logs "Failed to switch primary-plane scanout flags", its reset "Failed to render outputs", the outputs get written Disabled, and the next pass logs "Broken config, all outputs disabled" and generates preferred modes (60 Hz) in connector order into `~/.local/state/cosmic-comp/outputs.ron`, Xwayland primary included. Upstream master has the same code. The fix is a client: remember the layout per head set once it has sat still 2 s; when heads came or went and a known set is back different, apply the remembered one as one `zwlr_output_configuration_v1` (scale, VRR and mirroring through the COSMIC extension, the Xwayland primary as its manager request after success), 3 tries at most; a change with no hotplug is the user's and is remembered. Gotchas: `cosmic-randr kdl` drops the refresh rate on a `list --kdl` round trip, and its per-output commands, `--test` included, auto-align the *other* outputs, so neither is a restore path. Reproduced and verified with a scratch wlr-output-power client (25 s off): the 60 Hz fallback with the primary flipped, restored 2 s after. |
| The swap | Done 2026-09-05: fresh installs on both paths (A from `vanilla-keyed`, checkpoint `v2`; B via `archinstall --config-url` on VM `ikigai-b`, checkpoint `v2-b`), greeter login, Super+W, Settings in Vicinae and the polkit card confirmed at the console. Found by path A: `pacman -Syu` upgrades the kernel mid-install and the running one can then load no new module, so ufw failed (nf_tables); archinstall's chroot has the same shape always. Fix 91d8947: `bin/ikigai-firewall` + `firewall/ikigai-firewall.service`, a first-boot oneshot when `iptables -V` fails at install time (Omarchy does the same at first login, plus `kernel-modules-hook`). Also 026953c: no `daemon-reload` hard failure in the chroot. `install/packages.sh` (5499385): cosmic-comp, cosmic-bg, cosmic-settings, cosmic-settings-daemon, cosmic-idle, cosmic-randr, cosmic-icon-theme, cosmic-sound-theme, cosmic-files, xdg-desktop-portal-cosmic, greetd replace the `cosmic` group (a pacman group, not a meta) and cosmic-greeter. Dropped: session, panel, applets, notifications, launcher, osd, workspaces, app-library, initial-setup, greeter, screenshot, terminal, text-editor, player, monitor, store, wallpapers (~400 MB). Nothing kept depends on anything dropped; the portal's unit has no cosmic-session dependency; the GTK portal stays as gtk4's dep; default handlers all resolve to ours. `system_actions` off the dropped binaries (77be597): Super+A → `vicinae toggle`, Super+W → `ikigai-shell taskview toggle` (71eb126), Super+P → `cosmic-settings displays`, TouchpadToggle unbound. `CosmicAppList` seed dropped (463894b). In-place smoke test on the VM: `pacman -Rs` of the drop list, greeter without pills, session units + portal up. VM-only gotcha: greetd was a dep of cosmic-greeter there and went with it (a fresh install names it). `ikigai.desktop` is the only session entry. No migration: v1 only ever existed on the VM. |

## Steps

Each step is built and verified on the Hyper-V VM (checkpoint `fresh-session-crate` is a
fresh install + session crate) before the next starts.

**A. Shell skeleton.** `shell/shell.qml` with a bar frame (clock only) and autohide;
`ikigai-shell.service` wanted by the target; `quickshell` in the package list; installer
copies `shell/` to `/usr/local/share/ikigai/shell`; `themes/tokyo-night/shell.json` +
theme-set plumbing; `config/ikigai/shell.json` seed. Harness: add `vm.sh screenshot`
(Hyper-V thumbnail) so shell work can be checked without the console.

**B. Taskbar.** Bridge client in QML (`Socket` + `SplitParser`, reconnect on failure,
snapshot → model). Pinned + running icons resolved through DesktopEntries by app id, running
indicator, click activates / click-again minimizes / middle-click closes, context menu with
pin/unpin and close. Task-view button: a workspace switcher popup fed by the bridge's
`workspaces` events (activate, move window).

**C. Launcher.** Built as a Quickshell panel, then replaced by Vicinae (2026-09-03, see the
Launcher row) once the patched Qt made layer-shell teardown safe on cosmic-comp.

**D. Notifications.** Done 2026-09-04, see the Notifications row.

**E. Tray, volume, OSD.** Done 2026-09-04, see the Status items row.

**F. Daemons.** Done 2026-09-04, with the lock screen (see the Lock row) instead of borrowing cosmic-greeter's locker.

**G. The swap.** Done 2026-09-05 (The swap, Polkit, Launcher, Settings app rows; README
7553159; both fresh installs, checkpoints `v2` and `v2-b`). Left: a new `docs/desktop.png`.

**H. Greeter + lock.** Both done (Greeter and Lock rows); cosmic-greeter dropped at the swap.
The first-login welcome card (First login row) landed 2026-09-05.

## After G (order decided 2026-09-05)

1. Welcome card (first login: keys, the rail, where settings live). Done 2026-09-05.
2. Settings card for the rail (autohide, scale; icon overrides on the app's menu). Skipped
   2026-09-05: `shell.json` by hand is enough for now.
3. Network and battery on the rail. Done 2026-09-05 (Battery and Network rows).
4. Installer UI: step list with spinner, elapsed time per step, last log line under the
   current step, failure tail; plain lines when there is no TTY (archinstall's chroot).
   Bash-only, in `install.sh`; gum only if branding wants it.
5. `kernel-modules-hook` in the package list (keeps the running kernel's modules after an
   upgrade until reboot); does not help the install itself, protects every upgrade after.
6. Polkit identity chooser; greeter keyboard layout from archinstall's choice.
7. Lock survives a shell restart. Done 2026-09-05: Lock.qml sets logind's LockedHint while
   the compositor holds the lock (`WlSessionLock.secure`) and reads it at startup, over the
   session path the launcher publishes as `IKIGAI_SESSION_PATH`. Same day, lock before
   sleep: the launcher holds a delay inhibitor (`systemd-inhibit … sleep infinity`, no D-Bus
   in the crate), on PrepareForSleep sends lock and polls `ikigai-shell session locked` up
   to 3 s before releasing, re-takes it on resume; Unlock is relayed only for our own
   session path. Verified on the VM: lock/restart-shell/unlock, and a real suspend (logind
   waited ~180 ms, resumed locked). Found and fixed on the way: every unlock killed the
   shell with an ext-session-lock `null_buffer` protocol error, hidden by Restart=on-failure
   as a 1 s rail flicker. Cause: the Qt layer-shell patch's null commit, which lock surfaces
   forbid; the patch now skips the commit for lock windows (packages/qt6-base/README.md).

8. Keyring, faillock and pacman hygiene, 2026-09-07. greetd moves to `/etc/pam.d/ikigai-greeter`
   (login stack + `pam_gnome_keyring` auth and `session auto_start`); `gcr-ssh-agent.socket`
   enabled globally, `SSH_AUTH_SOCK` set by `ikigai-session` on cosmic-comp and the user manager
   (the socket's own `set-environment` only reaches units, not the shortcuts' terminal); the
   Chromium entries get `--password-store=gnome-libsecret`. Lock and Login keep PAM's info lines
   (`pam_faillock` says "locked due to 3 failed logins (N minutes left)" as `pam_info`, not an
   error) and show them in place of "Wrong password". `pacman-contrib` + `paccache.timer`,
   `kernel-modules-hook` + `linux-modules-cleanup.service`; `ikigai-update` reports orphans and
   pacnews. Not verified on the VM yet: a fresh install with the keyring, a lockout on the greeter.

9. Bluetooth, fonts and multi-monitor, 2026-09-07. `shell/Bluetooth.qml` wraps Quickshell's
   `Quickshell.Bluetooth` (imported qualified: the singleton shares the name) like Power wraps
   UPower: default adapter, enabled/discovering, `listed` (paired first, nameless advertisers
   dropped), a connected count kept by an Instantiator since ObjectModel changes don't re-run
   filters over device properties; `BluetoothCard.qml` mirrors NetworkCard (discovering while
   shown, click = connect or pair + trust, right-click = Disconnect/Forget, battery). No agent:
   PIN pairing is cosmic-settings'. `noto-fonts-cjk` in PACMAN. Multi-monitor: `Screens.focused`
   (the activated toplevel's output, else primary), the switcher freezes it at open (its own focus
   claim deactivates the toplevel); `taskbar: "all"|"screen"` in shell.json via `Tasks.onScreen`;
   2026-09-08: the switcher went back to the primary. Windows shows Alt+Tab on the primary display
   whichever monitor the active window or the mouse is on (Microsoft Q&A 5842953; AltTabMod exists
   to move it to the mouse), and following the focused window put the card on the second monitor
   whenever the last switch had landed there. `Screens.focused` stays for the launcher;
   the greeter's card on the last user's primary, read from `/var/lib/ikigai/greeter/<user>`
   (tmpfiles, 1777) which `Screens.qml` writes on every `monitor` change. Toasts stay on the
   primary, as Windows has it. Not verified on hardware yet: the Bluetooth card (no adapter on
   the VM; `btvirt`/`mac80211_hwsim`-style testing is the next step), the greeter file.

## Apps (decided 2026-09-03)

Independent of the v2 steps: everything lands in the installer and README and works in
both sessions. Small commits, one concern each; a `vm.sh reset vanilla` + full install
first, since none has run since the Alt+Tab commits, and again at the end.

| Area | Decision |
|---|---|
| Dev | Done 2026-09-04: `github-cli`, `just` in `PACMAN`. uv/bun via mise, VS Code and Chromium out. `base-devel` already covers build-essential. |
| Claude Code | Done 2026-09-04 (`install/tools.sh`, step after configs so `~/.local/bin` is already on the seeded PATH). The native installer (`~/.local/bin/claude`, self-updating, matches upstream's release cadence), as a per-user step in the installer, skipped when `claude` already resolves. Not the AUR package: it wraps the same binary with `DISABLE_UPDATES=1` and pacman as the only updater, and Ikigai has no update command yet. |
| Firewall | Done 2026-09-04 (`install/firewall.sh`, `ufw-docker` from the AUR). `ufw` + `ufw-docker`, `install/firewall.sh`: deny incoming, allow outgoing, allow ssh only when `sshd.service` is enabled (the VM harness needs it), Docker containers → host DNS, `ufw-docker install`, `ENABLED=yes` + `systemctl enable ufw`. Arch ships no firewall at all; Docker's published ports bypass ufw without ufw-docker. |
| Video | Done 2026-09-04. `mpv` (hwdec, external subs, chapters, yt-dlp, scripting), `config/mpv/mpv.conf` seeded with `hwdec=auto-safe`; OSC colours from the palette via theme-build later. cosmic-player dropped at the swap. |
| Screenshots | Done 2026-09-04. `grim` + `slurp` + `satty` + `gpu-screen-recorder` (cosmic-comp serves ext-image-copy-capture, never wlr-screencopy: grim ≥ 1.5 works, wf-recorder and flameshot don't). `bin/ikigai-shot region\|screen\|record` on `Print` / `Shift+Print` / `Super+Shift+R` → `shell/Shot.qml` when the shell offers the `shot` IPC target, else slurp and the recorder directly. Picker: overlays map transparent with a blank cursor, grim freezes every output, the frozen image fades in with a pill: Region / Window / Screen × Snip / Edit / Record. Snip = clipboard + `~/Pictures/Screenshots`; Edit = satty; Record = `shell/Recorder.qml` execs gpu-screen-recorder (`-w region -region WxH+X+Y` or `-w <output>`, KMS path) with a rail badge (`RecordingBadge.qml`), SIGINT stops, path to the clipboard. Window mode uses a one-shot `geometry` request to the bridge. Open: cosmic-comp 1.7.0 paints the pointer into output captures with paint-cursors off (grim sends options 0; the blank cursor only applies after the next pointer frame; check on real hardware), the recorder is verified against a stub only (no GPU on the VM), multi-output untested. |
| Gaming | Done 2026-09-04 (`bin/ikigai-steam`; no GPU → `lib32-vulkan-swrast`, or pacman's provider prompt hangs a piped install). Not installed by default. `[multilib]` enabled in `pacman.conf` at install (before the first `-Syu`, like Omarchy). `bin/ikigai-steam`: `steam ttf-liberation gamemode gamescope mangohud` + the lib32 driver for `~/.local/state/ikigai/gpu` (`lib32-vulkan-radeon` / `lib32-vulkan-intel` / `lib32-nvidia-utils`), then launches Steam. Proton ships with Steam; README points at `protonup-qt` for Proton-GE. VM has no GPU: verify the packages and the client reaching login only. 2026-09-07: `scx-scheds` + `scx-tools` in `PACMAN`, `scx_loader` enabled with `scx_lavd` (`config/system/etc/scx_loader/config.toml`, Auto mode): a Rust build at nice 0 took Deadlock to 5 fps under EEVDF. `ikigai-steam` adds the user to `gamemode` (Arch's limits.d gives the group nice -10; a re-login applies). Nicing the build itself (ananicy-cpp, cargo `jobs`) skipped. Later 2026-09-07, after a research workflow on how Windows keeps the foreground game smooth: the zram drop-in had never been installed (`install/configs.sh` kept archinstall's stub, whose keys a drop-in overrides anyway) so swap was the 4 GiB default and full, and with swap full every reclaim evicts file pages, the game's assets first (31M `workingset_refault_file` since boot); fixed, with a `zram-resident-limit = ram / 3` and doctor warnings for a small or full zram0. Still to do, in order: hard `RLIMIT_NICE` is 0 so Wine's thread-priority mapping and gamemode's renice are no-ops (limits.d rule for `@wheel` + `-high %command%`, or `gamemode.ini` `renice=10` + `gamemoderun`; a re-login either way); ananicy-cpp renicing rustc/lld/cc1 to 19, the only weight LAVD 1.1.3 reads (no cgroup ops: `CPUWeight` and autogroup are inert under it); zram-aware sysctls (`vm.swappiness=100`, `vm.page-cluster=0`). A focus-follows boost (renice the focused scope, the shell knows both) is the Windows foreground-quantum analogue, only if dips remain after those. Refuted: LAVD `--performance`, MGLRU `min_ttl_ms`, `MemoryLow` on Steam's scope, RT for cosmic-comp, VRR (EDID reports `vrr_capable=0`), gamescope with CAP_SYS_NICE (breaks the overlay), IO scheduler/IOWeight (disk 1.6% busy), a containers slice. Separately, Deadlock's crashes are not the dips: five NVIDIA Xid 109 CTX SWITCH TIMEOUT faults across 2026-09-06/07, three before any of the above changes, a known 610.x open-module regression (Arch bbs 313841, Deadlock forum 151071); downgraded to the AUR 580xx LTS branch (`nvidia-580xx-dkms`, `nvidia-580xx-utils`, `lib32-nvidia-580xx-utils` 580.178.04, proprietary modules, builds on 7.2; install with `paru --batchinstall`, or the old lib32 pins `nvidia-utils=610`). The doctor nags while the pin is in. `install/packages.sh` still says `nvidia-open-dkms` for a fresh install. |
| Out | zoxide, localsend, chromium, VS Code, flameshot, Proton-GE as a package. |
| Qt rebuild | Done 2026-09-04: warm rebuild 33 s vs 8 min cold on the VM; `BUILD_WITH_PCH=OFF` because ccache can't cache PCH compilations. `ccache` into `PACMAN`; `ikigai-qt-wayland` sets `CMAKE_C[XX]_COMPILER_LAUNCHER=ccache` with `CCACHE_DIR=/var/cache/ikigai/ccache`. qt6-base moves 1–2× a month; pkgrel bumps then rebuild from cache in well under a minute. Ignoring qt6-base is out: the qt6 family is lockstep, a held qt6-base is a partial upgrade. |
| Docs | README rows: Dev (gh, just, Claude Code), Firewall, Video, Screenshots, Gaming (the command); Runtimes row notes that Arch builds mise without `self_update` (pacman owns it). At the swap: cosmic-files kept (only file manager), cosmic-screenshot and cosmic-text-editor dropped. |

Order: install test → dev + Claude Code → multilib + firewall → mpv → screenshots step 1 →
Steam command → docs → install test → `Shot.qml`.

## After v2

The update command (reconcile seeds; rebuild `session/`; re-copy
`shell/`), custom pacman repo with a PKGBUILD for `session/`, upstreaming the Qt patch
(`packages/qt6-base/`, built at install and on every qt6-base upgrade until a fixed Qt or
cosmic-comp lands; then the rebuild hook can go), second theme, ISO.

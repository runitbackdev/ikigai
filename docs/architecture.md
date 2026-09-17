# Architecture

## Config layering

cosmic-config reads `~/.config/cosmic/<C>/v<N>/<key>`, then falls back to the first hit
of `<C>/v<N>` on `XDG_DATA_DIRS`. On NixOS that is the system profile,
`/run/current-system/sw/share/cosmic`, which merges every package's `share/cosmic`:
cosmic-settings' own `defaults` for the shortcuts, Ikigai's `custom` and `system_actions`
(`config/cosmic`, packaged by `nix/pkgs/cosmic-config.nix`), and the theme package's
`CosmicTheme` and `CosmicBackground` files. The config package is `lib.hiPrio`, so a
collision with a stock file resolves to Ikigai's. Settings writes to `~/.config/cosmic`
and wins per key. Ikigai never touches that, with one exception: a user-layer
`CosmicTheme.Dark` would shadow the system theme, so the home module moves one it finds
to `~/.local/state/ikigai/backup/` at switch.

The system layer is one directory per config, not a per-key merge: cosmic-config takes
every key from the first directory it finds. Any config Ikigai ships must ship all of its
keys. The profile merge is why the shortcuts work: `defaults` from cosmic-settings and
`custom` from Ikigai land in the same `v1` directory.

App configs are the home module's (`nix/home/default.nix`). Where Home Manager has an
option Ikigai uses it (zsh, starship, fzf, mise, yazi, git, delta, bat, Ghostty, Zed,
GTK, the cursor); the rest are files linked from `config/` and from the theme package.
Nix owns those files: change a setting in the flake and rebuild. A file that was already
there is kept next to the new one as `.before-ikigai`. Zed's `settings.json` stays
writable, since Home Manager merges into it rather than replacing it. Three files their
apps write back are seeded once, only where nothing exists, and then yours: the rail's
`shell.json`, `btop.conf` and Vicinae's `settings.json`.

## Session

`ikigai.desktop` is the only session entry, built into the `ikigai-session` package. Its
`DesktopNames` is COSMIC so cosmic-settings' entries show.

`ikigai-session` (Rust, `session/`) starts cosmic-comp with `COSMIC_SESSION_SOCK`, reads
the one `set_env` message cosmic-comp writes (`WAYLAND_DISPLAY`, `DISPLAY`), imports it
into the user manager and starts `ikigai-session.target`. The units are
`systemd.user.services` in `nix/ikigai/session.nix`:

| Unit | |
|---|---|
| `ikigai-bg`, `ikigai-settings-daemon`, `ikigai-idle` | cosmic-bg, cosmic-settings-daemon, cosmic-idle under Ikigai names |
| `ikigai-bridge` | COSMIC's toplevel and workspace protocols as JSON lines on `$XDG_RUNTIME_DIR/ikigai-bridge.sock`. `just bridge` follows it |
| `ikigai-outputs` | the display layout, wlr-output-management |
| `ikigai-shell` | Quickshell on `shell.qml` from the `ikigai-shell` package, the plugins on `QML_IMPORT_PATH`. The system profile links the same files at `/run/current-system/sw/share/ikigai/shell` and `/run/current-system/sw/lib/qt6/qml`, where `just ipc` and the dev scripts find them |
| `vicinae` | `vicinae server`, wanted by `graphical-session.target`, with `XDG_CURRENT_DESKTOP=Ikigai` because Vicinae refuses layer-shell on anything called COSMIC |

The bridge pins cosmic-protocols at the rev cosmic-comp's `Cargo.lock` resolves
(`32283d7`). Toplevel manager v4; the legacy `move_to_workspace` is a no-op in comp.
ext-workspace sends `id` only for pinned workspaces, so unpinned ones are keyed by
Wayland object id.

`ikigai-session` also listens to logind and relays Lock and Unlock to the shell.

## Greeter

`services.greetd` runs `ikigai-greeter` as the `ikigai-greeter` user
(`nix/ikigai/greeter.nix`); its PAM service is `greetd`, with gnome-keyring. It is
cosmic-comp in kiosk mode with the Quickshell greeter as its only client. No daemon:
theme and wallpaper from `/run/current-system/sw/share/ikigai/theme`, sessions from
`/run/current-system/sw/share/wayland-sessions`, users from `/etc/passwd`, avatars from
AccountsService, the last user and their primary screen from
`/var/lib/ikigai/greeter/<user>`, which the shell writes. On success cosmic-comp exits
and greetd starts the session. The command is `bin/ikigai-greeter`.

## Lock and polkit

The shell draws ext-session-lock surfaces on every screen and checks the password through
PAM. It is also the session's polkit agent, so a privilege request is the same card with
the request written under the name.

## Restore

The shell writes `~/.local/state/ikigai/session.json` a moment after every window change
while the bridge is up. The compositor going away drops the bridge and cancels the pending
write, so a logout's mass close never empties the file. `ikigai-session` clears a marker in
`XDG_RUNTIME_DIR` at start; the shell sets it as restore begins, so a shell restart
mid-session does not replay.

## The compositor

cosmic-comp is Ikigai's fork: `nix/pkgs/cosmic-comp.nix` overrides nixpkgs' package with
the source of `runitbackdev/cosmic-comp`, branch `ikigai`, and the overlay puts it in
place of the stock one everywhere. The fixes are in [upstream.md](upstream.md). The first
of them is why: stock cosmic-comp drops a client that commits to a surface after
destroying its layer-shell or lock role, and Qt does that on every hide, so every Qt
layer-shell client died the first time it hid a window. Until 2026-09-14 Ikigai rebuilt
Qt's Wayland client around it; the fork fixes it in Smithay and Qt is stock again.

The fork is cut from COSMIC epoch 1.8.0. nixpkgs ships epoch 1.6.0 for the other
components (Settings, the portal, cosmic-bg and the rest). A known gap to watch until
nixpkgs catches up.

## The flake

A box is a personal flake in `/etc/nixos` (`templates/personal` is the shape). It imports
`ikigai.nixosModules.ikigai`, sets `ikigai.enable` and `ikigai.user`, and the rest is
defaults with an option each: `ikigai.gpu`, `ikigai.theme`, `ikigai.steam.enable`,
`ikigai.wifiCountry`, `ikigai.flake`. The module
(`nix/ikigai/`) is one file per concern:

| File | |
|---|---|
| `default.nix` | the options, the user, Home Manager |
| `desktop.nix` | the COSMIC packages, the shell, fonts, portals, dconf, keyring, Zen's policies |
| `session.nix` | the user units above |
| `greeter.nix` | greetd, the greeter user, PAM |
| `system.nix` | what [system.md](system.md) describes |
| `packages.nix` | the system half of the dev stack |
| `gpu.nix`, `steam.nix` | the driver, Steam |
| `compat.nix` | nix-ld, envfs |
| `nix.nix` | flakes, the binary cache, garbage collection |

`nix/home/default.nix` is the Home Manager module, applied to `ikigai.user` through
`home-manager.sharedModules`. `nix/pkgs/` is the overlay: the compositor fork, the shell,
its plugins, the session crate, the task manager's monitor crate (`monitor/`, GPL like
the shell, since it links Mission Center's wire types), the theme, the icons, the
commands, the fonts, `zen` and `zed`.

## Installer

The ISO (`nix/iso.nix`) is NixOS's minimal image with `ikigai-install`
(`nix/installer/ikigai-install`) on tty1 and a copy of the flake it was built from at
`/etc/ikigai`. The installer asks for the mode (replace, or dual next to Windows), the
disk, a hostname, a user and password, a timezone, a keyboard layout and a git identity;
detects the GPU; partitions; writes the personal flake to `/mnt/etc/nixos` from the
answers, the way `nixos-generate-config` writes `configuration.nix` (`templates/personal`
is the same shape, for a NixOS box that already exists), writes `hardware.nix` from
`nixos-generate-config`, starts a git
repository there and runs `nixos-install` from it. The password never enters the flake:
after the install it is set inside the new system with `chpasswd`, into `/etc/shadow`,
where `passwd` changes it later, so the flake can be pushed anywhere. From `boot.ps1`
the mode and the disk come from the kernel command line. Afterwards `/etc/nixos` is the
user's and `ikigai-update` rebuilds from it.

The same live system is a kexec image (`nix/kexec.nix`, a kernel and an initrd that
carries the whole system). `bin/ikigai-migrate`, run with sudo on an Arch Ikigai, gathers
the box's facts (user, uid, password hash, hostname, timezone, keyboard, locale, GPU, git
identity, the root and boot partitions) into `/ikigai-migrate.json`, fetches the image from
the `iso` release and kexecs into it; with the nvidia driver loaded a kexec'd kernel gets no
display, so there (or with `--firmware`) the image is staged on `/boot` as a one-shot
systemd-boot entry and the box reboots through the firmware once instead. The installer, in `ikigai.mode=migrate`, mounts that
root, removes everything of Arch from it while keeping `/home`, `/root`, `/opt`, `/srv`,
Docker, Bluetooth, NetworkManager, `/var/lib/ikigai`, the avatars, the machine id and the
ssh host keys, empties `/boot` of Arch's kernels and entries (Windows' files stay), writes
the flake from the facts with the same uid, and runs `nixos-install` into the same
filesystem. Nothing leaves the disk and nothing is backed up.

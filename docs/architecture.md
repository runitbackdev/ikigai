# Architecture

## Config layering

cosmic-config reads `~/.config/cosmic/<C>/v<N>/<key>`, then falls back to the first hit
of `<C>/v<N>` on `XDG_DATA_DIRS`. The session puts `/usr/local/share` before `/usr/share`,
so Ikigai ships its COSMIC config to `/usr/local/share/cosmic`. Settings writes to
`~/.config/cosmic` and wins per key. Ikigai never touches that.

The system layer is one directory, not a per-key merge: cosmic-config takes every key
from the first directory it finds. Any config Ikigai overlays must ship all of its keys.
The shortcuts config is why `install/configs.sh` symlinks `defaults` to the `/usr/share`
copy: shipping only `custom` and `system_actions` hid every stock binding.

App configs are seeded once into `~/.config`, only where nothing exists. The seed's hash
is recorded in `~/.local/state/ikigai/seeds`; `just config-diff` says which files are
current, behind or edited. `IKIGAI_FORCE=1` overwrites.

Theme files are Ikigai-owned and reapplied by `ikigai-theme-set`.

## Session

`ikigai.desktop` is the only session entry. Its `DesktopNames` is COSMIC so cosmic-settings'
entries show.

`ikigai-session` (Rust, `session/`) starts cosmic-comp with `COSMIC_SESSION_SOCK`, reads
the one `set_env` message cosmic-comp writes (`WAYLAND_DISPLAY`, `DISPLAY`), imports it
into the user manager and starts `ikigai-session.target`:

| Unit | |
|---|---|
| `ikigai-bg`, `ikigai-settings-daemon`, `ikigai-idle` | cosmic-bg, cosmic-settings-daemon, cosmic-idle under Ikigai names |
| `ikigai-bridge` | COSMIC's toplevel and workspace protocols as JSON lines on `$XDG_RUNTIME_DIR/ikigai-bridge.sock`. `just bridge` follows it |
| `ikigai-outputs` | the display layout, wlr-output-management |
| `ikigai-shell` | Quickshell, `/usr/local/share/ikigai/shell/shell.qml` |
| `vicinae` | upstream's unit, plus a drop-in setting `XDG_CURRENT_DESKTOP=Ikigai` because Vicinae refuses layer-shell on anything called COSMIC |

The bridge pins cosmic-protocols at what cosmic-comp 1.7.0 resolves. Toplevel manager v4;
the legacy `move_to_workspace` is a no-op in comp. ext-workspace sends `id` only for pinned
workspaces, so unpinned ones are keyed by Wayland object id.

`ikigai-session` also listens to logind and relays Lock and Unlock to the shell.

## Greeter

greetd runs `ikigai-greeter` as its own user under `/etc/pam.d/ikigai-greeter`, Arch's
login stack plus gnome-keyring. It is cosmic-comp in kiosk mode with the Quickshell
greeter as its only client. No daemon: theme and wallpaper from
`/usr/local/share/ikigai/theme`, users from `/etc/passwd`, avatars from AccountsService,
the last user and their primary screen from `/var/lib/ikigai/greeter/<user>`, which the
shell writes. On success cosmic-comp exits and greetd starts the session. Files in
`greeter/`.

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

cosmic-comp is Ikigai's fork (`cosmic-comp-ikigai` from the `[ikigai]` pacman repo,
`packages/cosmic-comp`), Arch's package plus the fixes in [upstream.md](upstream.md). The
first of them is why: stock cosmic-comp drops a client that commits to a surface after
destroying its layer-shell or lock role, and Qt does that on every hide, so every Qt
layer-shell client died the first time it hid a window. Until 2026-09-14 Ikigai rebuilt
Qt's Wayland client around it; the fork fixes it in Smithay and Qt is stock again.

## Installer

`install.sh` runs nine steps: preflight, packages, configs, tools, theme, services,
firewall, session, greeter. A step list with a spinner and the last log line on a
terminal, plain `==> [n/10]` lines without one or with `IKIGAI_PLAIN=1`. Everything a step
printed is in `~/.local/state/ikigai/install.log`; a failed step shows its last 20 lines.
AUR packages are built with makepkg; paru is installed for you, not used by the installer.
The installed commit is recorded, and `ikigai-update` reruns the steps whose inputs
changed since it.

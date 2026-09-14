# Upstream

What Ikigai works around that belongs in COSMIC, and what it would take to fix there.
Each entry: the symptom, where the workaround lives, the fix, and the size. Ordered by
what a fork would earn first. Started 2026-09-13; every entry re-checked against epoch-1.8.0 of cosmic-comp,
xdg-desktop-portal-cosmic and cosmic-settings-daemon (smithay e3d461a, cosmic-protocols
32283d7) on 2026-09-13, which is what Arch ships and what the runitbackdev forks branch from.

## cosmic-comp

### A commit after a layer-shell role is destroyed kills the client

Qt's Wayland plugin hides a layer-shell window by destroying the role and then committing
a null buffer. Smithay's commit hook stays on the surface after the role goes and cosmic-comp
answers the commit with a protocol error, so every Qt layer-shell client died the first
time it hid a window. Until 2026-09-14 Ikigai carried a patched `libQt6WaylandClient.so`,
rebuilt by a pacman hook on every qt6-base upgrade. Vicinae turns layer-shell off on any
desktop named COSMIC because of the same bug, so its unit gets `XDG_CURRENT_DESKTOP=Ikigai`;
that stays, since Vicinae keys on the name, not on the bug. Upstream: cosmic-comp#1590 and
smithay#1979, both open with no movement since 2026-03.

Fixed on the fork, 2026-09-13: Smithay `dc10f06c` returns early from the `wlr_layer` and
`session_lock` pre-commit hooks once the role object is dead, the check Drakulix named as
acceptable in smithay#1979; cosmic-comp `fee768c8` pins it. `just comp-test` is the proof:
stock Qt survives six hide/show cycles and two lock cycles under the fork and dies on the
first of each under stock. Not sent upstream yet. The Qt rebuild is gone with it; Qt is nixpkgs' stock package.

### `set_focus` ignores exclusive layer surfaces for one frame

`Shell::set_focus` (`src/shell/focus/mod.rs` 192) hands keyboard focus straight to a
window. The rule that an exclusive layer surface owns focus lives only in `refresh_focus`
(`focus_target_is_valid`, 624 onward), which runs once per loop and takes it back. Any activate request while an
exclusive overlay is up, a late one from the shell's own switch or an app raising itself,
gives the overlay a keyboard leave and enter a few milliseconds apart. The Alt+Tab card
used to read the leave as "something took over" and cancel; since 2026-09-13 it ignores
focus loss instead (`shell/Switcher.qml`). The launcher and lock make the same assumption
and could see the same blink.

Fix: run `focus_target_is_valid` in `set_focus`, keep the focus-stack append so the window
is next when the overlay closes. A few lines.

### In kiosk mode the child's exit goes unnoticed until something else wakes the loop

`cosmic-comp <command>` checks `try_wait` on the child at the end of every event-loop
iteration (`src/lib.rs` 225) and nothing else. With no clients left and no input, the loop
sleeps and the compositor outlives its command indefinitely; a stray connection to its
socket is enough to make it exit. Showed up in `just comp-test`, whose lock test ends with
the client's clean exit and nothing after it. Fixed on the fork 2026-09-14: a
`calloop::signals` source for SIGCHLD that does nothing but wake the loop, registered only
when a command was given. A dozen lines plus calloop's `signals` feature. Not sent upstream.

### No move or resize in cosmic-toplevel-management

The protocol activates, minimizes, maximizes and moves windows between workspaces, and that
is what `shell/Restore.qml` puts back after a restart. Exact position and size of a
floating window cannot be set, so restore places by workspace and state only.

Fix: a `set_geometry` request on `zcosmic_toplevel_manager_v1` in cosmic-protocols, its
handler in cosmic-comp, and the bridge sending it. About a day.

### Keyboard focus never reaches a lock surface on an empty desktop

cosmic-comp moves focus to a lock surface only while repairing a focus that became invalid.
With nothing focused it never does, and the password field would need a click.
`shell/Lock.qml` takes focus with an exclusive layer first, locks, then drops the layer.

Fix: set focus to the lock surface when the lock takes effect. Small.

### The pointer is painted into captures whatever the client asked (unconfirmed)

ext-image-copy-capture lets the client say whether cursors go in, and `shell/Shot.qml`
maps a blank-cursor overlay on every screen before grim runs on the assumption that
cosmic-comp ignores it. The code says otherwise: `image_copy_capture/render.rs` 432 reads
`session.draw_cursor()` and picks `CursorMode::None` without it, in 1.7.0 and 1.8.0 alike,
and grim 1.5.0 only sets `paint_cursors` with `-c`. A `grim` versus `grim -c` diff on
2026-09-13 showed no cursor either. Re-test with the overlay removed and the pointer parked
on a still screen before writing anything; the workaround may simply be unnecessary.

### A failed page flip on wake rewrites the output config

On NVIDIA (610.57 open) a DisplayPort monitor leaves the bus when it sleeps and waking
is a hotplug. cosmic-comp's first page flip after the modeset fails with EINVAL,
`Config::read_outputs` logs "Failed to switch primary-plane scanout flags", the outputs
are written Disabled, the next pass logs "Broken config, all outputs disabled" and
generates preferred modes at 60 Hz in connector order into `outputs.ron`. 1.8.0 has the
same code (`config/mod.rs` 404, `backend/kms/mod.rs` 1246); its only change here sorts
the fallback layout by connector name. `ikigai-outputs` (`session/src/bin/ikigai-outputs.rs`) remembers the layout and
puts it back.

Fix: retry the flip before declaring the config broken, and never persist a config the
driver rejected once. Medium; needs the hardware to test.

### Middle-click paste has no off switch

Primary selection is offered to every client and Ghostty, Qt and COSMIC apps have no
per-app switch. A patch that offers `zwp_primary_selection_device_manager_v1` to no
client (Smithay's `new_with_filter`) was built and verified on 2026-09-06 and dropped
because it needed a compositor rebuild on its own. Trivial once a fork exists; better as
a config key upstream.

### Middle-click autoscroll with pan cursors

Windows-style autoscroll everywhere. Was per-app: Zen through policy, the Chromium apps
through a blink flag; GTK, Qt and COSMIC apps had nothing. Only the compositor can do it
everywhere with the cursor, since it owns pointer position, cursor image and the frame
clock.

On the fork since 2026-09-14, off by default (`middle_click_autoscroll` in
cosmic-comp-config; Ikigai's system config turns it on): a middle press over a window
becomes an `AutoscrollGrab` (`src/shell/grabs/autoscroll.rs`) that holds the press back.
Released inside the dead zone the press and release are delivered together, an ordinary
click. Past the dead zone a timer emits continuous axis events to the surface under the
press every 8 ms at Chromium's `0.000008 * d^2.2` px/ms per axis, the pointer moves freely
with the client keeping focus as under an implicit grab, and the cursor is one of nine pan
shapes loaded by name (`pan-all`, `pan-n`, `pan-ne`, ...) with the resize arrows and
`all-scroll` as fallbacks (`CursorShape` in `backend/render/cursor.rs`). Windows with an
active pointer constraint, app ids in `exclude`, and presses with Super held are passed
through. Ikigai draws the pan cursors (`cursors/ikigai`). Not sent upstream yet; a
feature, not a fix, and the config key would want a Settings page.

### Not yet diagnosed

- `Failed to render texture ..., import for wrong devices DrmNode { ty: Render }` in the
  compositor log while the switcher's previews are captured (2026-09-12). Two GPUs on
  this box; the bridge's thumbnail capture may be handed a buffer from the wrong render
  node. Harmless so far.
- New windows open on the active output, which follows keyboard focus, so after login or
  a wake they land wherever the compositor put focus. `shell/Screens.qml` nudges focus to
  the primary. A primary-output setting upstream would replace that; design, not a bug.

## xdg-desktop-portal-cosmic

### A window share outlives its window

Share a window in Discord and close that window: the stream stays up on the last frame.
cosmic-comp sends `stopped` on the capture session; the portal's handler
(`src/wayland/mod.rs` 724, "TODO signal users of session in some way?", unchanged in 1.8.0) sets a flag and
the PipeWire thread quits, but nothing emits `Closed` on the
`org.freedesktop.impl.portal.Session` object. `closed` is only sent from the `Close`
method (`src/main.rs` 122), so the frontend never tells the app and Chromium's capturer
treats "no frame" as temporary. GNOME and KDE emit `Closed` here. PR #291 (merged
2026-04-01) made the portal survive the event instead of crashing and left
this. No issue filed.

Fix, about 40 lines: give `ScreencastThread` a stopped notification (a oneshot fired in
`process` next to the existing `thread_stop_tx.send`), spawn a task at the end of
`capture_from_sources` that awaits it, and have it do what `Close` does: build a
`SignalEmitter` for the session path, emit `closed`, remove the interface, run the close
callback. Guard on `closed` against a client `Close` racing it. Keep quitting the loop
rather than `stream.disconnect()`, which the PR notes segfaults.

## cosmic-settings-daemon

"Failed to sync with greeter" (`src/main.rs` 495) on every start: it writes state for cosmic-greeter and
Ikigai's greeter reads nothing there. Noise only. A patch would make the greeter sync
optional or quiet when the greeter directory is absent.

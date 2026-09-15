# The shell

Ikigai's shell is Quickshell, run by `ikigai-shell.service` from `/run/current-system/sw/share/ikigai/shell`.
A rounded frame around the desktop, a thin rail that autohides into its left border, cards
that melt out of the rail. One rail per screen.

## Rail

Pinned and running apps at the top, the status items and clock at the bottom.

- Click focuses, again minimizes, middle-click closes.
- Right-click: pin, unpin, move.
- An app's tray item sits on its own button.
- The launcher's window never counts as a running app, and its tray icon is not shown.
- Task view (`Super+W`): this screen's workspaces and their windows.

## Cards

| | |
|---|---|
| Volume | level, mute, output picker. Scroll on the glyph steps it |
| Caffeine | the cup keeps the screen on: click toggles until turned off, right-click picks 30 or 90 minutes or 3 hours. `ikigai-shell caffeine toggle` from a key; a caffeinate started in a terminal is its own |
| Microphone | shown while an app has a capture stream open, red when live; click mutes the input |
| Update | an arrow while `ikigai-update --available` says there is something, asked two minutes after login and every six hours; click runs the update in a terminal |
| Network | Wi-Fi switch, the wired link, networks in range. Click connects; a new secured network asks for its password. The connected row expands to Disconnect and Forget. VPNs: cosmic-settings |
| Bluetooth | switch, paired devices, what is in range while the card is open. Click pairs and connects; battery where the device reports one. PIN or confirmation pairing: cosmic-settings, the card has no agent |
| Battery | time left, the power profile. Only when there is one |
| Tray | StatusNotifier items, menus. Submenus are not rendered |
| Clock | opens the sidebar |

## Notifications

Toasts out of the frame's top border on the primary screen. App timeout or 5 s, none for
critical, paused under the pointer. Click runs the default action; middle-click, the X in
the corner, or a swipe to the right dismisses. A square image (an avatar) sits in the icon
slot, a wide one is a banner.

The sidebar (click the clock, `ikigai-shell sidebar toggle`): history, calendar, the bell
is do-not-disturb, the broom clears. The clock carries the unread count.

Volume and brightness changes show a pill at the bottom edge.

## Launcher

Vicinae on `Super`: apps, files, clipboard history, power commands. It drops out of the
frame's top border as a card; Escape, a launch or a click beside it lifts it back.
`ikigai-shell launcher toggle`.

## Task manager

`Ctrl+Shift+Escape`, Task Manager in Vicinae, or `ikigai-shell monitor toggle`. The same
drop as the launcher, with two pages:

- Processes: apps first, each a row with its processes under a caret and its numbers
  summed, then everything else under Background processes. Name, PID, CPU, memory, GPU and
  GPU memory; a click on a column sorts, and the sort holds while the card is up. Typing
  searches by name or PID. End task sends TERM to the selected row's processes, Force stop
  sends KILL; `Delete` and `Shift+Delete` do the same. The cell tint is the heat map.
- Performance: CPU, memory and each GPU down the left with a minute of history, the chosen
  one on the right with its graph and numbers. A click on the CPU graph shows every logical
  processor.

`Ctrl+Tab` flips the page. An app is a window's app id matched to processes by the binary
its desktop entry runs, plus their descendants; the rest is background.

The numbers are Mission Center's: `ikigai-monitor` (`monitor/`, Rust) runs its data daemon
(`missioncenter-magpie`, from nixpkgs' mission-center) for as long as the card is open, asks
it over its nng socket for the CPU, memory, GPUs, processes and apps once a second (twice on
Performance) and prints each sample as a JSON line, which `Monitor.qml` reads. Nothing runs
while the card is closed.

## Switcher

`Alt+Tab`, Windows-style. Hold Alt, Tab cycles live previews most-recent-first across
workspaces, minimized included. Release switches, Shift+Tab goes back, Escape cancels,
a click picks a tile, its close button closes the window. Always on the primary screen.

## Screenshots

`Print` freezes the screen and opens the picker: Region, Window or Screen, then Snip,
Edit or Record. `Shift+Print` starts on Screen.

- Snip: PNG to the clipboard and `~/Pictures/Screenshots`.
- Edit: the PNG in satty.
- Record: gpu-screen-recorder with system audio, a dot and timer on the rail.
  `Super+Shift+R` or a click on the dot stops it and puts the path (`~/Videos/Recordings`)
  on the clipboard. x264 on the CPU when the GPU encoder is unavailable; a failure is a
  notification.

`ikigai-shot region|screen|record` from a terminal. Without the shell it falls back to
grim, slurp and gpu-screen-recorder directly.

## Lock and polkit

`Super+Escape`, the idle timeout or the lid. The shell draws the card over every screen and
checks the password through PAM. Polkit prompts are the same card with the request under
the name. The card says when Caps Lock is on, in the greeter too. After three wrong
passwords faillock locks the account for ten minutes and the card says so.

## Restore

Log back in and the apps you had come back, each on its output and workspace, maximized
if it was. The app, not its contents, except Ghostty's tabs: each comes back in the
directory it was in, the way Windows Terminal does it, with the first window holding the
extras when there were several. Off with `"restore": false`.

## First login

A welcome card: keys, the rail, where settings live, Connect to Wi-Fi if offline. Once per
user; `ikigai-shell welcome open` brings it back.

## Middle-click autoscroll

Everywhere, the way Windows does it, by the compositor fork. Hold the middle button and
move: past 15 px the window under the press scrolls, faster the further the pointer is
from the press, on Chromium's curve, until the button is released. The cursor is the
origin ring, then an arrow the way you are heading. A middle press released inside the
15 px is delivered as an ordinary click, so paste, close-tab and open-in-new-tab still
work; a press that scrolled is never seen by the app. Apps that need the middle button
for a drag (Blender) go in the `exclude` list of
`/run/current-system/sw/share/cosmic/com.system76.CosmicComp/v1/middle_click_autoscroll`,
by app id; a copy under `~/.config/cosmic` overrides it, `enabled: false` turns it off.
Zen's and Chromium's own autoscroll are left off, since a middle click must stay a click.

Middle-click paste is off, everywhere: the compositor fork offers the primary selection
to no client (`primary_selection` in the same directory, `true` brings it back for apps
started after the change). Select-to-copy goes with it; the clipboard is untouched.

## Settings

cosmic-settings, with the rail in place of its panel. The Panel and Dock pages are inert.

The rail's own settings are `~/.config/ikigai/shell.json`, seeded once, reloaded live:

| Key | Default | |
|---|---|---|
| `pinned.top`, `pinned.bottom` | Ghostty, Zen, Zed; YouTube Music, Discord | app ids, by desktop entry |
| `icons` | `{}` | app id to icon name overrides |
| `autohide` | `true` | |
| `scale` | `1.0` | |
| `dnd` | `false` | do-not-disturb; the sidebar's bell writes it |
| `monitor` | `""` | the primary screen: toasts, lock, polkit, welcome, the switcher, and the greeter's card. Empty is the first output the compositor lists |
| `restore` | `true` | |
| `taskbar` | `"all"` | `"screen"` shows each rail only its own screen's windows |

## IPC

cosmic-comp's shortcuts call the shell over `ikigai-shell <target> <call>`. `just ipc`
lists the targets.

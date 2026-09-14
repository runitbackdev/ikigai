# The shell

Ikigai's shell is Quickshell, run by `ikigai-shell.service` from `/run/current-system/sw/share/ikigai/shell`.
A rounded frame around the desktop, a thin rail that autohides into its left border, cards
that melt out of the rail. One rail per screen.

## Rail

Pinned and running apps at the top, the status items and clock at the bottom.

- Click focuses, again minimizes, middle-click closes.
- Right-click: pin, unpin, move.
- An app's tray item sits on its own button.
- Task view (`Super+W`): this screen's workspaces and their windows.

## Cards

| | |
|---|---|
| Volume | level, mute, output picker. Scroll on the glyph steps it |
| Network | Wi-Fi switch, the wired link, networks in range. Click connects; a new secured network asks for its password. The connected row expands to Disconnect and Forget. VPNs: cosmic-settings |
| Bluetooth | switch, paired devices, what is in range while the card is open. Click pairs and connects; battery where the device reports one. PIN or confirmation pairing: cosmic-settings, the card has no agent |
| Battery | time left, the power profile. Only when there is one |
| Tray | StatusNotifier items, menus. Submenus are not rendered |
| Clock | opens the sidebar |

## Notifications

Toasts out of the frame's top border on the primary screen. App timeout or 5 s, none for
critical, paused under the pointer. Click runs the default action, middle-click dismisses.

The sidebar (click the clock, `ikigai-shell sidebar toggle`): history, calendar, the bell
is do-not-disturb, the broom clears. The clock carries the unread count.

Volume and brightness changes show a pill at the bottom edge.

## Launcher

Vicinae on `Super`: apps, files, clipboard history, power commands. It drops out of the
frame's top border as a card; Escape, a launch or a click beside it lifts it back.
`ikigai-shell launcher toggle`.

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
if it was. The app, not its contents. Off with `"restore": false`.

## First login

A welcome card: keys, the rail, where settings live, Connect to Wi-Fi if offline. Once per
user; `ikigai-shell welcome open` brings it back.

## Middle-click autoscroll

Per app, the way Windows does it. Zen through `/etc/zen/policies/policies.json`, Discord
and YouTube Music through `--enable-blink-features=MiddleClickAutoscroll` on their desktop
entries in `/run/current-system/sw/share/applications`. GTK, Qt and COSMIC apps have none.

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

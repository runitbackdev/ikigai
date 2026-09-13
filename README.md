# Ikigai

A reason to boot.

![Ikigai desktop](docs/desktop.png)

## What is it

A developer desktop on Arch Linux, installed with one command onto a fresh box.

cosmic-comp does the windows. Everything you look at is Ikigai's: a Quickshell shell
with a thin rail and cards that melt out of it, the launcher, notifications, greeter,
lock and polkit prompt, and one palette rendered into every app. Under that, a dev stack
picked once so you don't have to: Ghostty, Zed, Zen, zsh, Docker, mise, the TUIs, and
the system tuning that makes a build and a game share a box.

It is opinionated and it asks nothing. Your dotfiles are never overwritten, Settings
still works, and every choice below has an off switch.

## Install

Ikigai layers onto an Arch install; it does not replace one.

On Arch already:

```sh
curl -fsSL https://raw.githubusercontent.com/runitbackdev/ikigai/main/boot.sh | bash
```

From the Arch ISO. archinstall picks the minimal profile, systemd-boot and
NetworkManager, asks for disk, user, password, locale and timezone, then runs the line
above:

```sh
archinstall --config-url https://raw.githubusercontent.com/runitbackdev/ikigai/main/archinstall.json
```

From Windows, no USB stick. Admin PowerShell, Secure Boot and BitLocker off:

```powershell
irm https://raw.githubusercontent.com/runitbackdev/ikigai/main/boot.ps1 | iex
```

It asks replace or dual boot, puts the ISO on a small partition and boots it once.
Windows is untouched until you confirm the disk in archinstall; `-Undo` before that puts
everything back. After a dual boot, run it once with `-Clean` from Windows.

One sudo prompt, about ten minutes, `sudo reboot`.

Tested on a fresh minimal Arch. On a box with a desktop already it works, best-effort:
your dotfiles are left alone, the greeter takes `display-manager.service`.

## What's in it

- COSMIC's compositor (Ikigai's fork, [docs/upstream.md](docs/upstream.md)), Settings, Files and portal. Panel, launcher, notifications, OSD, greeter, lock and polkit are Ikigai's ([docs/shell.md](docs/shell.md)).
- One palette rendered into the shell, COSMIC, GTK, Qt, Ghostty, btop, Vicinae and the cursors ([docs/theme.md](docs/theme.md)).
- [Vicinae](https://vicinae.com) launcher, [Ghostty](https://ghostty.org) + [zellij](https://zellij.dev), zsh + [starship](https://starship.rs), [Zed](https://zed.dev), Neovim, [Zen](https://zen-browser.app), mpv, cosmic-viewer, Discord, YouTube Music.
- gh, just, Claude Code, mise, Docker + lazydocker, yazi, lazygit, btop, ripgrep, fd, fzf, bat, eza, dust, delta, tealdeer, jq, plocate, fastfetch.
- JetBrainsMono Nerd Font, Noto with CJK and emoji.
- PipeWire, NetworkManager, bluez, gnome-keyring unlocked at login, ufw, zram, systemd-oomd, the LAVD scheduler ([docs/system.md](docs/system.md)).
- Steam on demand: `ikigai-steam`.

## Keys

cosmic-comp's stock bindings, plus:

| Key | |
|---|---|
| `Super`, `Super+A`, `Super+/` | Vicinae |
| `Super+W` | task view |
| `Super+Escape` | lock |
| `Alt+Tab`, `Alt+Shift+Tab` | window switcher: hold, cycle, release |
| `Super+Return`, `Super+T` | Ghostty |
| `Super+E` | Zed |
| `Super+B` | Zen |
| `Print`, `Shift+Print` | screenshot picker, region or screen |
| `Super+Shift+R` | record; again to stop |
| `Super+Shift+/` | cheatsheet |

Log out, power off, reboot and sleep are Vicinae commands: `Super`, type the word.

## Commands

| | |
|---|---|
| `ikigai-update` | packages, then pull Ikigai and rerun the steps that changed. `--pkg`, `--no-pkg` for one half |
| `ikigai-doctor` | what is installed, running, patched and drifted |
| `ikigai-keys` | every binding. `--fzf` to search |
| `ikigai-caffeinate` | keep the screen on: until Ctrl-C, `-t 90m`, `-w PID`, or around a command |
| `ikigai-shot` | `region`, `screen` or `record` |
| `ikigai-steam` | Steam, gamemode, gamescope, mangohud, the 32-bit driver |
| `ikigai-theme-set` | apply a theme from `themes/` |
| `ikigai-shell welcome open` | the first-login card again |

## Docs

- [shell.md](docs/shell.md): the rail, its cards, `shell.json`
- [system.md](docs/system.md): what Ikigai changed under the hood and why
- [theme.md](docs/theme.md): the palette pipeline
- [architecture.md](docs/architecture.md): session, greeter, lock, config layering
- [hacking.md](docs/hacking.md): repo layout, just recipes, the VM
- [upstream.md](docs/upstream.md): what belongs in COSMIC, and what a fork would fix first

## Credits

The rail is a port of [caelestia-shell](https://github.com/caelestia-dots/shell) by
[soramanew](https://github.com/soramanew): the frame-and-rail layout, the motion, and the
blob renderer that draws every panel as a signed distance field. Ikigai vendors that plugin
verbatim (`shell/plugin/blobs`) and rewrites the QML around it for cosmic-comp. If you like
how this looks, that's their work.

## License

MIT, except `shell/`, which is GPL-3.0 because it builds on caelestia-shell's renderer.
Vendored files: [THIRD_PARTY.md](THIRD_PARTY.md).

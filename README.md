# Ikigai

A reason to boot.

![Ikigai desktop](docs/desktop.png)

## What is it

A developer desktop on NixOS, described by one flake, installed from a USB stick or from
Windows.

cosmic-comp does the windows. Everything you look at is Ikigai's: a Quickshell shell
with a thin rail and cards that melt out of it, the launcher, notifications, greeter,
lock and polkit prompt, and one palette rendered into every app. Under that, a dev stack
picked once so you don't have to: Ghostty, Zed, Zen, zsh, Docker, mise, the TUIs, and
the system tuning that makes a build and a game share a box.

It is opinionated and it asks nothing. Every app config is in the flake, Settings still
works, and every choice below is an option with an off switch.

## Install

Ikigai is a NixOS module. Your box is a small personal flake in `/etc/nixos` that
imports it and sets a handful of `ikigai.*` options; the installer writes that flake.

From a USB stick. Write the ISO from the
[`iso` release](https://github.com/runitbackdev/ikigai/releases/tag/iso) to a stick and
boot it. `ikigai-install` asks for the disk, a user, a password, a hostname and a
timezone, then runs `nixos-install`.

From Windows, no USB stick. Admin PowerShell, Secure Boot and BitLocker off:

```powershell
irm https://raw.githubusercontent.com/runitbackdev/ikigai/main/boot.ps1 | iex
```

It asks replace or dual boot, stages the same ISO on a small partition and boots it
once. Windows is untouched until you confirm the disk in `ikigai-install`; `-Undo`
before that puts everything back. After a dual boot, run it once with `-Clean` from
Windows.

On Arch Ikigai already, in place. Nothing leaves the disk: the installer boots from RAM
over the running system, empties the root of Arch and installs into it, keeping your home,
Docker, Bluetooth, Wi-Fi, avatars, ssh host keys and your uid:

```sh
curl -fsSL https://raw.githubusercontent.com/runitbackdev/ikigai/main/bin/ikigai-migrate | sudo bash
```

It shows what it found and asks for the hostname to confirm; `--dry-run` stops there. A box
with the nvidia driver loaded reboots through the firmware into the installer (a kexec'd
kernel gets no display there); `--firmware` asks for that on any box.

On NixOS already:

```sh
cd /etc/nixos
sudo nix flake init -t github:runitbackdev/ikigai#personal
```

Edit `hosts/ikigai/default.nix` (user, GPU, hostname, timezone), rename
`users/alice.nix` to yours, put `nixos-generate-config --show-hardware-config` in
`hardware.nix`, then `sudo nixos-rebuild switch --flake /etc/nixos`. Passwords are
never in the flake: `passwd` sets them.

Settings live in that flake: `ikigai.user`, `ikigai.gpu`, `ikigai.theme`,
`ikigai.steam.enable`, `ikigai.nvidia.pin580`, `ikigai.wifiCountry`. Edit, then
`ikigai-update --no-pull`.

The Arch path was retired on 2026-09-14. The NixOS install is under dogfooding: CI
builds every package and the example system, and the install itself has not yet been
run on hardware or in a VM.

## What's in it

- COSMIC's compositor (Ikigai's fork, [docs/upstream.md](docs/upstream.md)), Settings, Files and portal. Panel, launcher, notifications, OSD, task manager, greeter, lock and polkit are Ikigai's ([docs/shell.md](docs/shell.md)).
- One palette rendered into the shell, COSMIC, GTK, Qt, Ghostty, btop, Vicinae and the cursors ([docs/theme.md](docs/theme.md)).
- [Vicinae](https://vicinae.com) launcher, [Ghostty](https://ghostty.org) + [zellij](https://zellij.dev), zsh + [starship](https://starship.rs), [Zed](https://zed.dev), Neovim, [Zen](https://zen-browser.app), mpv, cosmic-viewer, Discord, YouTube Music.
- gcc, make, pkg-config, rustup, gh, just, Claude Code, mise, Docker + lazydocker, yazi, lazygit, btop, ripgrep, fd, fzf, bat, eza, dust, delta, tealdeer, jq, plocate, fastfetch.
- JetBrainsMono Nerd Font, Noto with CJK and emoji.
- PipeWire, NetworkManager, bluez, gnome-keyring unlocked at login, the firewall, zram, systemd-oomd, the LAVD scheduler ([docs/system.md](docs/system.md)).
- nix-ld and envfs, so the binaries mise, Zed and Claude Code download run as they would elsewhere.
- Steam on demand: `ikigai.steam.enable`, then `ikigai-steam`.

## Keys

cosmic-comp's stock bindings, plus:

| Key | |
|---|---|
| `Super`, `Super+A`, `Super+/` | Vicinae |
| `Super+W` | task view |
| `Super+Escape` | lock |
| `Ctrl+Shift+Escape` | task manager |
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
| `ikigai-update` | pull the personal flake, update its inputs, rebuild and switch, restart the shell. `--no-pull` rebuilds from the inputs as locked, `--check` shows what would change, `--available` only says whether anything is newer |
| `ikigai-doctor` | what is running: the flake, the session units, the greeter, the compositor fork, scheduler, zram, firewall |
| `ikigai-keys` | every binding. `--fzf` to search |
| `ikigai-caffeinate` | keep the screen on: until Ctrl-C, `-t 90m`, `-w PID`, or around a command |
| `ikigai-shot` | `region`, `screen`, `text` (OCR to the clipboard), `color` (a pixel as hex) or `record` |
| `ikigai-steam` | Steam, once `ikigai.steam.enable` put it there; pins it to the rail |
| `ikigai-shell welcome open` | the first-login card again |

## Docs

- [shell.md](docs/shell.md): the rail, its cards, `shell.json`
- [system.md](docs/system.md): what Ikigai changes under the hood and why
- [theme.md](docs/theme.md): the palette pipeline
- [architecture.md](docs/architecture.md): session, greeter, lock, config layering, the flake
- [hacking.md](docs/hacking.md): repo layout, just recipes, the VM, the binary cache
- [upstream.md](docs/upstream.md): COSMIC dependencies, downstream fixes, and workarounds
- [review-2026-09.md](docs/review-2026-09.md): desktop audit, downstream-only fork policy, portability, and remaining DE work

## Credits

The rail is a port of [caelestia-shell](https://github.com/caelestia-dots/shell) by
[soramanew](https://github.com/soramanew): the frame-and-rail layout, the motion, and the
blob renderer that draws every panel as a signed distance field. Ikigai vendors that plugin
verbatim (`shell/plugin/blobs`) and rewrites the QML around it for cosmic-comp. If you like
how this looks, that's their work.

## License

MIT, except `shell/`, which is GPL-3.0 because it builds on caelestia-shell's renderer.
Vendored and fetched files: [THIRD_PARTY.md](THIRD_PARTY.md).

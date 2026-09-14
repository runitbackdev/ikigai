# System

What Ikigai changes below the desktop, and why. Everything here is an option in
`nix/ikigai/system.nix` (the driver in `gpu.nix`, Steam in `steam.nix`, outside binaries
in `compat.nix`, Nix itself in `nix.nix`); the personal flake can override any of them.

## Secrets

gnome-keyring, unlocked by the greeter's PAM stack (`security.pam.services.greetd`) with
the login password. Zen, Zed, gh, Vicinae and the Chromium apps
(`--password-store=gnome-libsecret`) keep their tokens there and never ask twice. The ssh
agent is gcr's; `SSH_AUTH_SOCK` is set by the session, passphrases land in the same
keyring.

## Displays

`ikigai-outputs` remembers each layout that has sat still and puts it back when the same
heads return different. On NVIDIA a DisplayPort monitor leaves the bus when it sleeps, so
waking is a hotplug; cosmic-comp's first page flip after the modeset fails, it falls back
to 60 Hz in connector order and saves that. `ikigai-outputs` undoes that. A change made in
Settings has no hotplug and sticks.

## Memory

zram the size of RAM, zstd, before any disk swap (`services.zram-generator`), with a
resident limit of a third of RAM so incompressible data cannot eat the memory it
relieves. `vm.swappiness=100` and no swap readahead: swap is RAM, so the kernel should
compress a build's idle pages before it drops a game's mapped files.

systemd-oomd kills the one runaway app when the apps' slice has sat under memory pressure
or swap is nearly full. The shell and compositor are never candidates.

## Scheduler

sched_ext's LAVD instead of EEVDF, loaded by `services.scx-loader` at boot. EEVDF shares
the CPU per thread, so a 12-thread build drops a game to single digits. LAVD spots the
tasks that wake and sleep between frames and lets them preempt the build. `scxctl stop`
is EEVDF again, live. The kernel is `linuxPackages_latest`: sched_ext needs 6.12.

## Boot and shutdown

`NetworkManager-wait-online` is off: the desktop never waits on DHCP. A stuck service
gets 5 s at shutdown, Docker 30 to stop its containers.

## Firewall

NixOS's: deny incoming, allow outgoing. sshd opens its own port when it is enabled.
Docker's published ports bypass it, as they did ufw.

## Updates

`ikigai-update` pulls the personal flake when it is a clean checkout with an upstream,
moves every input (Ikigai, nixpkgs) to its latest, rebuilds and switches, and restarts
the shell when the system changed. `--no-pull` rebuilds from the inputs as locked, which
is how an edit to the flake is applied; `--check` builds and shows the diff without
switching.

The old generation stays in the boot menu, ten of them, so a bad update is a reboot away
from undone. Garbage collection runs weekly and drops generations older than 14 days.
There is no package cache to prune, no orphans, no `.pacnew`, and a kernel update cannot
unload the running kernel's modules.

## Outside binaries

A developer box downloads binaries all day: mise's toolchains, Zed's language servers,
Claude Code's installer. nix-ld gives them the loader and a generous library list
(`compat.nix`), envfs the `/usr/bin` shebangs, and `programs.appimage` with binfmt runs
AppImages directly.

## Fixes

- ssh notices a dropped connection within a minute (`programs.ssh.extraConfig`; `~/.ssh/config` wins).
- The Wi-Fi regulatory domain follows the timezone's country, read from tzdata's `zone.tab`; `ikigai.wifiCountry` sets it outright.
- Apple keyboards get F-keys on the F row (`hid_apple fnmode=2`).
- Cosmic Files is pinned for folders so no other entry wins `inode/directory`.
- Zen is the default for links and PDFs at the lowest XDG layer; Settings' Default Apps overrides it.

## NVIDIA

`ikigai.gpu = "nvidia"` picks the driver. `ikigai.nvidia.pin580` (on by default) keeps
`hardware.nvidia.package` on the `legacy_580` branch with the proprietary modules: the
610.x open modules crash Proton games with Xid 109. `ikigai-doctor` nags while the pin is
in. Sleep is set up (`hardware.nvidia.powerManagement.enable`): the driver keeps video
memory across suspend and its suspend, resume and hibernate services run, so the
compositor wakes to a GPU that still has its state. Not yet seen on hardware; idle-suspend
on AC stays off in the COSMIC config until it has.

## Gaming

Not installed by default. `ikigai.steam.enable = true` in the flake, then `ikigai-update`,
puts Steam, the 32-bit driver, gamemode, gamescope, mangohud and Proton-GE on the box and
you in the gamemode group. gamemode renices a game to -10, the one weight LAVD reads
(its stock renice is 0), and turns split-lock throttling off while a game runs.
`ikigai-steam` pins Steam to the rail and launches it. Proton comes with Steam.

## Docker

You are in the `docker` group, which is root-equivalent.

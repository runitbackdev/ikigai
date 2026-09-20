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
(`compat.nix`), envfs the `/usr/bin` shebangs.

## Fixes

- ssh notices a dropped connection within a minute (`programs.ssh.extraConfig`; `~/.ssh/config` wins).
- The Wi-Fi regulatory domain follows the timezone's country, read from tzdata's `zone.tab`; `ikigai.wifiCountry` sets it outright.
- Apple keyboards get F-keys on the F row (`hid_apple fnmode=2`).
- Cosmic Files is pinned for folders so no other entry wins `inode/directory`.
- Zen is the default for links and PDFs at the lowest XDG layer; Settings' Default Apps overrides it.

## NVIDIA

`ikigai.gpu = "nvidia"` selects `nvidiaPackages.production` (595.x) with open kernel
modules. `production` follows the version in the flake's locked nixpkgs and advances with
normal `ikigai-update`; `--no-pull` retains the locked version. Take a driver change with
`ikigai-update --boot` and reboot: a switch puts the new userspace on the old kernel
module until then, and GPU clients started in between fall to llvmpipe. The `ikigai.nvidia.pin580` option has been removed;
delete any explicit assignment to it from a personal flake before rebuilding.

The earlier pin followed Xid 109 crashes, but the cited
[Arch report](https://bbs.archlinux.org/viewtopic.php?id=313841) does not establish that
open modules caused them: one 3090 user recovered by moving from 610.43.02 to 595.58.03
while retaining open modules. The return to latest on 2026-09-17 was a test and it
failed: 580.178.04 logged no Xid from 2026-09-14 to 2026-09-18, while 610.57.04 logged
eight Xid 109 (CTX SWITCH TIMEOUT) in two days of Deadlock, with and without gamescope,
and one of them took Xwayland down with it. Production is the next test, since 595 is
what cured the 3090 in that report; if it hangs too, the known-good setup on our box is
`legacy_580` with `open = false`. Try latest again once it has left the 610 branch.
After a game session, check
`journalctl -k -b | grep -i 'NVRM: Xid'`; no matches means no Xid was logged this boot,
not proof that all GPU faults are gone. The previous NixOS generation remains available
in the boot menu. `ikigai-doctor` reports the loaded version.

Sleep is set up (`hardware.nvidia.powerManagement.enable`): the driver keeps video
memory across suspend and its suspend, resume and hibernate services run, so the
compositor wakes to a GPU that still has its state. Not yet seen on hardware; idle-suspend
on AC stays off in the COSMIC config until it has.

## Gaming

Not installed by default. `ikigai.steam.enable = true` in the flake, then `ikigai-update`,
puts Steam, the 32-bit driver, gamemode, gamescope, mangohud and Proton-GE on the box and
you in the gamemode group. `ikigai-steam` pins Steam to the rail and launches it.

Stock Proton stays the default. Select GE-Proton per game under Properties >
Compatibility when needed. Nix supplies GE through `extraCompatPackages`; normal
`ikigai-update` updates it when the new nixpkgs input contains a newer package.
`--no-pull` retains the locked version, and Steam's own updates do not update this GE
package. Fully quit and restart Steam after rebuilding to discover the new tool path.
The dropdown name stays `GE-Proton` across package updates.

Steam-enabled systems load the `ntsync` kernel module at boot. GE uses it automatically
when supported; selecting GE alone cannot load the module. On the reference box,
loading it manually made the missing `/dev/ntsync` device available. Confirm use with
`sudo lsof /dev/ntsync` while the game runs. If the device is absent, try
`sudo modprobe ntsync`; if it exists but is unused, check the selected runner and device
permissions. `ikigai-doctor` checks device availability and access, not whether a game
is using it.

Steam exports `MANGOHUD=1`, enabling the overlay for Vulkan games, including DXVK and
vkd3d-proton. OpenGL games still need `mangohud %command%`. To disable the Vulkan overlay
for one game, use `MANGOHUD=0 %command%`. MangoHud is available inside Steam's FHS
environment as well as on the system.

On NVIDIA, Steam also exports `__GL_SHADER_DISK_CACHE_SIZE=10737418240` (10 GiB).
Cleanup stays enabled. This targets repeated shader compilation like that reported in
[Steam issue 11392](https://github.com/ValveSoftware/steam-for-linux/issues/11392);
its benefit on our box is unmeasured. Driver changes invalidate compiled shaders, so
warm the cache before comparing sessions. Steam-enabled systems also set
`vm.max_map_count=2147483642` to accommodate games with many mappings; this is a limit,
not a RAM allocation. The existing zram sysctls remain in effect.

gamemode stays per game: `gamemoderun %command%` renices a game to -10, a weight LAVD
reads (gamemode's stock renice is 0), and turns split-lock throttling off while the game
runs. Use it when builds compete with a game. gamescope also stays per game, for cursor,
resolution or fullscreen fixes. LAVD stays in Auto mode without gamemode scheduler hooks.
Compare frame-time logs and 1% lows with and without a build running; change one variable
at a time. Driver stability and Overwatch DX11 versus DX12 still need hardware testing.

## Docker

You are in the `docker` group, which is root-equivalent.

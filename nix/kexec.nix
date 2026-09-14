# The same live system as a kexec image: a kernel and an initrd that carries the whole
# system, so a running Linux box boots into the installer from RAM with no stick, no
# partition and no reboot through the firmware. `ikigai-migrate` on an Arch Ikigai fetches
# it from the `iso` release and kexecs into it. `nix build .#kexec` gives bzImage,
# initrd.gz and a kexec-boot script.
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/netboot/netboot-minimal.nix"
    ./installer/live.nix
  ];
}

# Ikigai, from Windows.
#
#   irm https://raw.githubusercontent.com/runitbackdev/ikigai/main/boot.ps1 | iex
#
# Stages the Arch ISO on a small new partition of this disk and reboots into it once.
# The ISO then runs windows/live.sh, which runs archinstall (Windows is erased there,
# not here) and Ikigai's own installer. Everything this script does is undone by -Undo.
#
#   & ([scriptblock]::Create((irm <url>))) -Mode dual -GB 200
[CmdletBinding()]
param(
  [string]$Mode,
  [int]$GB = 0,
  [string]$Ref = 'main',
  [switch]$Undo,
  [switch]$Clean,
  [switch]$Yes,
  [switch]$NoReboot,
  [string]$Raw
)

$ErrorActionPreference = 'Stop'
$Label = 'IKIGAI'
$StageGB = 2
$Description = 'Ikigai installer'
$Mirror = 'https://geo.mirror.pkgbuild.com/iso/latest'
if (-not $Raw) { $Raw = "https://raw.githubusercontent.com/runitbackdev/ikigai/$Ref" }

function Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Note($text) { Write-Host "    $text" -ForegroundColor DarkGray }

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole('Administrators')) {
    throw 'run this from an administrator PowerShell'
  }
}

function Get-Target {
  $part = Get-Partition -DriveLetter C
  $disk = Get-Disk -Number $part.DiskNumber
  $sizes = Get-PartitionSupportedSize -DriveLetter C
  [pscustomobject]@{
    Disk      = $disk
    Partition = $part
    ShrinkGB  = [math]::Floor(($part.Size - $sizes.SizeMin) / 1GB)
  }
}

function Test-BitLocker {
  # Numeric status from WMI rather than parsing manage-bde's localized text.
  # ProtectionStatus 0 = off, ConversionStatus 0 = fully decrypted.
  $vol = Get-CimInstance -Namespace root/cimv2/Security/MicrosoftVolumeEncryption `
    -ClassName Win32_EncryptableVolume -Filter "DriveLetter='C:'" -ErrorAction SilentlyContinue
  if (-not $vol) { return $true }
  $prot = (Invoke-CimMethod -InputObject $vol -MethodName GetProtectionStatus).ProtectionStatus
  $conv = (Invoke-CimMethod -InputObject $vol -MethodName GetConversionStatus).ConversionStatus
  ($prot -eq 0) -and ($conv -eq 0)
}

function Test-Preflight($target) {
  Step 'Checking this machine'
  if ($env:firmware_type -ne 'UEFI') { throw 'this PC boots in legacy BIOS mode; Ikigai needs UEFI' }
  Note 'UEFI firmware'

  if (Confirm-SecureBootUEFI) {
    throw "Secure Boot is on. The Arch ISO is unsigned and will not boot.`n" +
      "    Turn it off in your firmware settings (usually Del or F2 at power-on), then run this again.`n" +
      "    It stays off: Arch does not sign its kernels."
  }
  Note 'Secure Boot off'

  if ($target.Disk.PartitionStyle -ne 'GPT') { throw "disk $($target.Disk.Number) is $($target.Disk.PartitionStyle), not GPT" }
  Note "disk $($target.Disk.Number): $($target.Disk.FriendlyName), $([math]::Round($target.Disk.Size / 1GB)) GB, GPT"

  if (-not (Test-BitLocker)) {
    throw "C: is BitLocker-encrypted. The ISO has to be readable at boot: run 'manage-bde -off C:' " +
      "and wait for 'Fully Decrypted' in 'manage-bde -status C:', then run this again."
  }
  Note 'BitLocker off'

  $ramGB = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
  if ($ramGB -lt 3.5) { throw "only $([math]::Round($ramGB, 1)) GB RAM; the installer runs from memory and needs 4 GB" }
  Note "$([math]::Round($ramGB)) GB RAM"

  $need = $StageGB + $(if ($Mode -eq 'dual') { $GB } else { 0 })
  if ($target.ShrinkGB -lt $need) {
    throw "C: can only shrink by $($target.ShrinkGB) GB, need $need. Free up space, or run 'defrag C: /X' and try again"
  }
  Note "C: can shrink by $($target.ShrinkGB) GB, need $need"
}

# A plain data partition on purpose: typed as ESP, Windows drops its volume and letter
# until a reboot, and -Undo could not find it. UEFI loads the boot file by partition
# and path and does not care about the type.
function Get-Stage($target) {
  Get-Partition -DiskNumber $target.Disk.Number | Get-Volume -ErrorAction SilentlyContinue |
    Where-Object FileSystemLabel -eq $Label | Get-Partition | Select-Object -First 1
}

# Shrink C: and put a small FAT32 partition in the gap. In dual mode the gap is bigger
# than the partition: the rest stays free for the root filesystem. A rerun finds the
# partition from the last time and reuses it.
function New-Stage($target) {
  $stage = Get-Stage $target
  if ($stage) { Note "reusing the $Label partition ($($stage.DriveLetter):)"; return $stage }

  Step 'Making room'
  $take = $StageGB + $(if ($Mode -eq 'dual') { $GB } else { 0 })
  if ((Get-Disk -Number $target.Disk.Number).LargestFreeExtent -ge $take * 1GB - 64MB) {
    Note "using the $take GB already free"
  }
  else {
    Resize-Partition -DriveLetter C -Size ($target.Partition.Size - $take * 1GB)
    Note "C: shrunk by $take GB"
  }

  # A little under the gap: GPT's backup table and alignment take the last few MB of a disk.
  $stage = New-Partition -DiskNumber $target.Disk.Number -Size ($StageGB * 1GB - 64MB) -AssignDriveLetter
  Format-Volume -Partition $stage -FileSystem FAT32 -NewFileSystemLabel $Label -Confirm:$false | Out-Null
  $stage = Get-Partition -DiskNumber $stage.DiskNumber -PartitionNumber $stage.PartitionNumber
  Note "$Label partition is $($stage.DriveLetter): ($StageGB GB)"
  $stage
}

# The ISO from a mirror, its checksum from archlinux.org: two hosts have to agree.
function Get-Iso($stage) {
  $iso = "$($stage.DriveLetter):\archlinux-x86_64.iso"
  $version = (Invoke-RestMethod "$Mirror/arch/version").Trim()
  $sums = Invoke-RestMethod "https://archlinux.org/iso/$version/sha256sums.txt"
  $want = ($sums -split "`n" | Where-Object { $_ -match '\sarchlinux-x86_64\.iso$' }) -replace '\s.*'
  if (-not $want) { throw "no sha256 for archlinux-x86_64.iso $version on archlinux.org" }

  if (-not (Test-Path $iso) -or (Get-FileHash $iso -Algorithm SHA256).Hash -ne $want) {
    Step "Downloading Arch Linux $version"
    # Start-Process: curl's progress bar is stderr, which PowerShell 5.1 would treat as an error.
    $curl = Start-Process curl.exe -NoNewWindow -Wait -PassThru -ArgumentList @(
      '--location', '--fail', '--retry', '5', '--continue-at', '-', '--progress-bar',
      '--output', $iso, "$Mirror/archlinux-x86_64.iso")
    if ($curl.ExitCode -ne 0) { throw "download failed (curl exit $($curl.ExitCode))" }
    if ((Get-FileHash $iso -Algorithm SHA256).Hash -ne $want) { throw 'the downloaded ISO does not match its checksum' }
  }
  Note "archlinux-x86_64.iso $version verified"
  $iso
}

# The ISO's own systemd-boot, kernel and initramfs, at the paths its loader entry
# expects. The initramfs loop-mounts the ISO next to them and copies it to RAM, so
# the disk is free by the time the live system is up.
function Install-Boot($stage, $iso) {
  Step 'Staging the boot'
  $d = "$($stage.DriveLetter):"
  Mount-DiskImage -ImagePath $iso | Out-Null
  try {
    $src = $null
    foreach ($i in 1..20) {
      $src = (Get-DiskImage -ImagePath $iso | Get-Volume).DriveLetter
      if ($src) { break }
      Start-Sleep 1
    }
    if (-not $src) { throw 'the mounted ISO got no drive letter' }
    New-Item -ItemType Directory -Force "$d\EFI\BOOT", "$d\arch\boot\x86_64", "$d\loader\entries" | Out-Null
    Copy-Item "${src}:\EFI\BOOT\BOOTx64.EFI" "$d\EFI\BOOT\"
    Copy-Item "${src}:\arch\boot\x86_64\vmlinuz-linux", "${src}:\arch\boot\x86_64\initramfs-linux.img" "$d\arch\boot\x86_64\"
  }
  finally { Dismount-DiskImage -ImagePath $iso | Out-Null }

  $options = "archisobasedir=arch img_label=$Label img_loop=/archlinux-x86_64.iso copytoram=y " +
    "script=$Raw/windows/live.sh ikigai.mode=$Mode ikigai.ref=$Ref ikigai.raw=$Raw"
  [IO.File]::WriteAllText("$d\loader\loader.conf", "timeout 3`ndefault ikigai.conf`n")
  [IO.File]::WriteAllText("$d\loader\entries\ikigai.conf",
    "title Ikigai installer`nlinux /arch/boot/x86_64/vmlinuz-linux`ninitrd /arch/boot/x86_64/initramfs-linux.img`noptions $options`n")
  Note 'systemd-boot, kernel, initramfs and loader entry in place'
}

# A firmware boot entry cloned from Windows' own, pointed at the staging partition,
# and queued for the next boot only: if it fails, Windows is back on the boot after.
function Add-BootEntry($stage) {
  Step 'Queuing the installer for the next boot'
  $out = bcdedit /copy '{bootmgr}' /d $Description
  $id = [regex]::Match("$out", '\{[0-9a-f-]+\}').Value
  if ($LASTEXITCODE -ne 0 -or -not $id) { throw "bcdedit /copy failed: $out" }
  bcdedit /set $id device "partition=$($stage.DriveLetter):" | Out-Null
  bcdedit /set $id path '\EFI\BOOT\BOOTx64.EFI' | Out-Null
  bcdedit /set '{fwbootmgr}' bootsequence $id | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'bcdedit could not queue the boot entry' }
  Note "boot entry $id, once"
}

# Windows rewrites its BCD firmware entries into NVRAM on every boot, so the one-shot
# entry can only be removed for good from here. After a dual-boot install that is all
# there is to clean up: -Clean.
function Remove-BootEntry {
  $entries = (bcdedit /enum firmware) -join "`n" -split "`n`n" |
    Where-Object { $_ -match [regex]::Escape($Description) } |
    ForEach-Object { [regex]::Match($_, '\{[0-9a-f-]+\}').Value }
  foreach ($id in $entries) { bcdedit /delete $id | Out-Null; Note "removed boot entry $id" }
  if (-not $entries) { Note 'no installer boot entry to remove' }
}

function Undo-Ikigai($target) {
  Step 'Undoing'
  Remove-BootEntry

  $stage = Get-Stage $target
  if ($stage) { Remove-Partition -InputObject $stage -Confirm:$false; Note "removed the $Label partition" }

  $max = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
  if ($max - $target.Partition.Size -gt 1MB) {
    Resize-Partition -DriveLetter C -Size $max
    Note "C: grown back to $([math]::Round($max / 1GB, 1)) GB"
  }
  Step 'Done: this PC is as it was'
}

try {
  Assert-Admin
  $target = Get-Target
  if ($Undo) { Undo-Ikigai $target; return }
  if ($Clean) { Step 'Cleaning up after the install'; Remove-BootEntry; return }

  if (-not $Mode) {
    Write-Host "  replace  erase Windows, Ikigai gets the whole disk"
    Write-Host "  dual     keep Windows, Ikigai gets part of C:"
    $Mode = (Read-Host 'Mode [replace/dual]').Trim().ToLower()
  }
  if ($Mode -notin 'replace', 'dual') { throw "not a mode: $Mode" }
  if ($Mode -eq 'dual' -and $GB -lt 20) {
    $GB = [int](Read-Host "GB for Ikigai (20 or more, up to $((Get-Target).ShrinkGB - $StageGB))")
    if ($GB -lt 20) { throw 'Ikigai needs at least 20 GB' }
  }

  Test-Preflight $target
  if (-not $Yes) {
    $pc = $env:COMPUTERNAME
    if ($Mode -eq 'replace') { Write-Host "This erases Windows and everything else on $pc's disk." -ForegroundColor Yellow }
    else { Write-Host "This shrinks C: by $($GB + $StageGB) GB and installs Ikigai next to Windows on $pc." -ForegroundColor Yellow }
    if ((Read-Host "Type $pc to continue") -cne $pc) { throw 'not confirmed, nothing changed' }
  }
  if ($Mode -eq 'dual') {
    # Fast startup leaves NTFS half-hibernated; Linux then refuses to mount it read-write.
    powercfg /h off
    Note 'hibernation and fast startup off, so Linux can mount C:'
  }
  $stage = New-Stage $target
  $iso = Get-Iso $stage
  Install-Boot $stage $iso
  Add-BootEntry $stage

  Step 'Ready'
  Write-Host "    On restart this PC boots the Arch installer once. It asks for a user, a password"
  Write-Host "    and a timezone, confirms the disk, installs Ikigai and reboots into it."
  Write-Host "    Windows is untouched until you confirm that disk. Changed your mind? Run this with -Undo."
  if ($Mode -eq 'dual') {
    Write-Host "    Afterwards systemd-boot lists both Ikigai and Windows. The first time you are back in"
    Write-Host "    Windows, run this once with -Clean to drop the leftover 'Ikigai installer' boot entry."
  }
  if ($NoReboot) { Note 'not restarting (-NoReboot)'; return }
  Restart-Computer -Force
}
catch {
  Write-Host "boot.ps1: $($_.Exception.Message)" -ForegroundColor Red
}

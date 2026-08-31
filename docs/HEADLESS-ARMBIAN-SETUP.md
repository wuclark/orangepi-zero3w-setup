# Headless Armbian setup

This is the starting point for an Orange Pi Zero 3W with 12 GB RAM. It uses
the official [Orange Pi Zero 3W Armbian page](https://armbian.com/boards/orangepizero3w)
and the Debian 13 (Trixie), Minimal (CLI), arm64 image marked `vendor 6.6.98`.
Do not substitute a Current/mainline image for the confirmed PVR stack.

## Download and verify

Use the board page's Debian 13 direct-download link, SHA checksum, and optional
PGP signature. The exact filename and checksum can change as Armbian republishes
images, so record both in your setup notes. Do not trust an image that does not
match its published SHA-256 value.

The official [Armbian first-boot preset documentation](https://docs.armbian.com/User-Guide_Autoconfig/)
requires `/root/.not_logged_in_yet` on the image's root filesystem. The Wi-Fi
key and passwords are necessarily plaintext in this temporary file. Keep it
local, use a private SD card, and delete it after the first successful SSH login.

## Write the image

Use Armbian Imager (recommended) or a raw image writer. Select the SD card by
size and physical device; never guess a Linux `/dev/sdX` or macOS `/dev/diskN`.
Eject the card after writing and before inserting it into the board.

Linux checksum and writing example:

```bash
sha256sum Armbian_*.img.xz
sudo xzcat Armbian_*.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync,status=progress
sudo sync
```

On macOS use `shasum -a 256`, `diskutil list`, `diskutil unmountDisk /dev/diskN`,
and `sudo dd ... of=/dev/rdiskN bs=4m`; use the raw device only after checking
the disk identity. On Windows use `Get-FileHash`, Armbian Imager, or a trusted
raw-image writer. The repository does not contain or redistribute Armbian images.

## Create the first-boot file

On Linux, mount the second (root) partition and run:

```bash
sudo ./scripts/create-headless-preset.sh --root-mount /mnt/armbian-root
```

To create a file for copying later instead:

```bash
./scripts/create-headless-preset.sh --output ./not_logged_in_yet
```

On Windows PowerShell:

```powershell
.\windows\Prepare-HeadlessPreset.ps1 -OutputFile .\not_logged_in_yet
```

On macOS, generate the file with the same PowerShell command if PowerShell 7
is installed, or use a Linux VM/live system to mount the ext4 root partition
and run the Bash generator. macOS's normal tools do not safely provide a
writable ext4 mount. Copy the generated file to the root partition as
`root/.not_logged_in_yet` before ejecting the card.

The generators prompt for hostname, username, root password, user password,
Wi-Fi SSID, and Wi-Fi password. They use US Wi-Fi country settings, DHCP, and
the Pacific timezone. The default values are `orangepi` for both hostname and
username, but can be changed during generation.

## First boot and SSH

Insert the card, connect power, and allow several minutes for first boot. Find
the DHCP lease in your router, or try mDNS:

```bash
ssh orangepi@orangepi.local
```

If the username or hostname was changed, use those values. Immediately remove
the preset if it was copied into the live system and then confirm the target:

```bash
sudo rm -f /root/.not_logged_in_yet
hostnamectl
uname -a
ip addr
```

Do not run the PVR installer until SSH is stable and the board reports the
expected `6.6.98-vendor-sun60iw2` kernel. The delayed GPU module ordering is
safety-critical.

## Optional software menu

The base image installs no additional packages by default. After SSH works,
run this only if you want to choose software:

```bash
cd ~/zero3w-pvr-forge
sudo ./scripts/armbian-provision.sh
```

Press Enter at the menu to install nothing. The PVR/GPU stack remains a
separate, deliberate installation described in [Fresh Armbian installation](FRESH-ARMBIAN-INSTALL.md).

## Recovery

If Wi-Fi does not come up, power down, mount the root partition on another
Linux system, inspect `/root/.not_logged_in_yet`, correct it, and retry. Keep
UART/serial access available during GPU bring-up; do not shorten the delayed
module-load service as a remote recovery strategy.

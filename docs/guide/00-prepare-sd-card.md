# Prepare the SD card

This is the starting point for a new Orange Pi Zero 3W. Prepare the card on a
separate computer before powering the board. The confirmed PVR path uses the
official Armbian Debian 13 (Trixie), Minimal (CLI), arm64 image marked
`vendor 6.6.98`; do not substitute a Current/mainline image.

## What you need

- Orange Pi Zero 3W with the supported 12 GB configuration
- A reliable microSD card and reader
- The official Armbian image and its published SHA-256 checksum
- A way to mount the image's ext4 root partition, if you want to install the
  first-boot preset before inserting the card

The exact image filename and checksum can change as Armbian republishes images.
Download them from the official [Orange Pi Zero 3W Armbian page](https://armbian.com/boards/orangepizero3w)
and record the filename and checksum in your setup notes. The repository does
not contain or redistribute Armbian images.

## Verify the download

Verify the image before writing it. If Armbian publishes a PGP signature, use
that as an additional check. A checksum verifies the download; it does not
prove that the file came from Armbian, so obtain the checksum from the official
board page.

Linux:

```bash
sha256sum Armbian_*.img.xz
```

macOS:

```bash
shasum -a 256 Armbian_*.img.xz
```

Windows PowerShell:

```powershell
Get-FileHash .\Armbian_*.img.xz -Algorithm SHA256
```

Compare the complete hash, then continue only if it matches the published
value.

## Write the image

[Armbian Imager](https://www.armbian.com/imager/) is the recommended writer.
Select the SD card by its capacity and physical identity, not only by the
device name. Writing an image overwrites the selected device. Close programs
that may be using the card, and eject it from the operating system after the
write completes.

On Linux, first inspect the devices and identify the whole SD-card device (for
example, `/dev/sdX`), not one of its partitions:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
sudo xzcat Armbian_*.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync,status=progress
sudo sync
```

Replace `/dev/sdX` only after checking the device identity. Never use the
repository path, a mounted partition such as `/dev/sdX2`, or an unverified
device guess.

On macOS, inspect the disk first and unmount the whole device without ejecting
it:

```bash
diskutil list
diskutil unmountDisk /dev/diskN
sudo xzcat Armbian_*.img.xz | sudo dd of=/dev/rdiskN bs=4m
sync
diskutil eject /dev/diskN
```

Use the raw device (`/dev/rdiskN`) only after confirming the disk number from
`diskutil list`. On Windows, use Armbian Imager or another trusted raw-image
writer, then safely eject the card. Do not use ordinary file copy; the image
contains the partition layout and boot data.

## Create the temporary first-boot preset

After writing, the card normally has a small boot partition and a larger ext4
root partition. The preset belongs at:

```text
/root/.not_logged_in_yet
```

On Linux, mount the larger root partition at `/mnt/armbian-root` and run this
from the repository:

```bash
sudo mkdir -p /mnt/armbian-root
sudo mount /dev/sdX2 /mnt/armbian-root
sudo ./scripts/create-headless-preset.sh --root-mount /mnt/armbian-root
sudo umount /mnt/armbian-root
```

Confirm the partition number with `lsblk`; it may differ from `/dev/sdX2`.
Unmount the card before removing it.

If the computer cannot safely mount ext4, create the file separately and copy
it to the mounted root partition's `root/` directory:

```bash
./scripts/create-headless-preset.sh --output ./not_logged_in_yet
```

On Windows:

```powershell
.\windows\Prepare-HeadlessPreset.ps1 -OutputFile .\not_logged_in_yet
```

PowerShell can also write directly when an ext4 root filesystem is available:

```powershell
.\windows\Prepare-HeadlessPreset.ps1 -RootMountPath "X:\"
```

The normal Windows workflow is to generate the file, use a Linux system or
ext4-capable tool to copy it to `root/.not_logged_in_yet`, and then safely
eject the card. macOS's standard tools do not provide a safe writable ext4
mount; use PowerShell 7 in a suitable environment or a Linux VM/live system.

## What the preset scripts do

`create-headless-preset.sh` and `Prepare-HeadlessPreset.ps1` are generators;
they do not download, partition, or write the Armbian image. They prompt for:

- hostname and username;
- root and user passwords; and
- Wi-Fi SSID and password.

They write Armbian's first-boot variables for Wi-Fi, DHCP, US Wi-Fi
regulatory settings, `en_US.UTF-8`, and `America/Los_Angeles`. The Bash
generator validates the mount by checking for an `etc` directory, creates the
destination with restrictive permissions, and uses mode `600`. The PowerShell
generator uses a secure prompt for passwords while prompting, but the generated
file necessarily contains plaintext values because Armbian requires them.

Keep the file private, do not commit it, and delete it immediately after the
first successful SSH login. It is temporary bootstrap material, not a general
configuration file.

## Continue to first boot

Insert the prepared card, connect the board to power, and allow several minutes
for Armbian's first boot. Continue with [First boot and Wi-Fi](01-first-boot-wifi.md).

Keep UART/serial access available before optional GPU installation. The PVR
module has a safety-critical delayed-load requirement; a successful SD-card
boot alone is not evidence that the GPU stack is compatible.

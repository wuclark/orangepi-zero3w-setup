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

If the computer cannot safely mount ext4, create the files separately and copy
both to the mounted root partition's `root/` directory:

```bash
./scripts/create-headless-preset.sh --output ./not_logged_in_yet
```

This creates `not_logged_in_yet` and `provisioning.sh` in the current directory.
Copy them to `/root/.not_logged_in_yet` and `/root/provisioning.sh`.

On Windows:

```powershell
.\windows\Prepare-HeadlessPreset.ps1 -OutputFile .\not_logged_in_yet
```

This also creates `provisioning.sh`; copy it to `/root/provisioning.sh` with the
preset file.

### Windows with WSL2 and a USB card reader

WSL2's `wsl --mount` command does not directly support USB SD-card readers.
Use Microsoft's [USB connection workflow](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)
with `usbipd-win` instead. Close File Explorer and any Windows disk utility
using the card first.

In **Administrator PowerShell**, find the reader and note its bus ID:

```powershell
usbipd list
usbipd bind --busid 1-4
usbipd attach --wsl --busid 1-4
```

Replace `1-4` with the bus ID shown by `usbipd list`. The `bind` command is
normally needed once per device; `attach` makes it available to WSL2. Then,
inside WSL, identify the Armbian root partition:

```bash
lsblk -f
sudo mkdir -p /mnt/armbian-root
sudo mount -t ext4 /dev/sdX2 /mnt/armbian-root
```

Replace `/dev/sdX2` after checking `lsblk`; the larger ext4 partition is the
root filesystem. Generate the preset from WSL:

```bash
cd /path/to/orangepi-zero3w-setup
sudo ./scripts/create-headless-preset.sh --root-mount /mnt/armbian-root
sudo umount /mnt/armbian-root
```

After unmounting, detach the reader from **PowerShell**:

```powershell
usbipd detach --busid 1-4
```

Do not remove the card or reuse it in Windows until the WSL mount has been
unmounted and the USB device detached.

PowerShell can also write directly when an ext4 root filesystem is available:

```powershell
.\windows\Prepare-HeadlessPreset.ps1 -RootMountPath "X:\"
```

The normal Windows workflow is to generate the file, use a Linux system or
ext4-capable tool to copy it to `root/.not_logged_in_yet`, and then safely
eject the card. macOS's standard tools do not provide a safe writable ext4
mount; use PowerShell 7 in a suitable environment or a Linux VM/live system.

## Optionally copy vendor archives before first boot

If the repository is already copied to the card at
`/home/orangepi/orangepi-zero3w-setup`, you can also place the user-supplied
archives on the card now. Keep them as unchanged tarballs; do not extract them
into the Armbian root filesystem:

```text
/home/orangepi/orangepi-zero3w-setup/vendor-files/
├── pvr-userspace.tar.gz
├── vpu-userspace.tar.gz       # optional VPU userspace
└── npu-userspace.tar.gz       # optional experimental NPU userspace
```

On Linux, with the Armbian root partition mounted at `/mnt/armbian-root` and
the archives in `./work/vendor-output/`:

```bash
sudo install -d -o root -g root -m 0755 \
  /mnt/armbian-root/home/orangepi/orangepi-zero3w-setup/vendor-files
sudo install -o root -g root -m 0644 \
  ./work/vendor-output/pvr-userspace.tar.gz \
  /mnt/armbian-root/home/orangepi/orangepi-zero3w-setup/vendor-files/
sudo install -o root -g root -m 0644 \
  ./work/vendor-output/vpu-userspace.tar.gz \
  /mnt/armbian-root/home/orangepi/orangepi-zero3w-setup/vendor-files/
sudo install -o root -g root -m 0644 \
  ./work/vendor-output/npu-userspace.tar.gz \
  /mnt/armbian-root/home/orangepi/orangepi-zero3w-setup/vendor-files/
```

Omit the VPU or NPU command when that optional archive is unavailable.
The archives are installer inputs, not executable files; root ownership with
directory mode `0755` and file mode `0644` is appropriate. If an ext4-capable
Windows tool assigns different ownership, correct it after first login:

```bash
sudo chown root:root ~/orangepi-zero3w-setup/vendor-files/*
sudo chmod 0644 ~/orangepi-zero3w-setup/vendor-files/*
```

This step is optional. If the repository or archives are not placed on the
card, use `windows/Copy-VendorArchives.ps1` after SSH becomes available.
Generate all three archives before this step with
`scripts/extract-vendor-userspace-docker.sh`; the NPU archive remains
experimental and is not installed by the current setup flow.

## What the preset scripts do

`create-headless-preset.sh` and `Prepare-HeadlessPreset.ps1` are generators;
they do not download, partition, or write the Armbian image. They prompt for:

- username;
- root and user passwords; and
- Wi-Fi SSID and password.

They write only Armbian's documented first-boot variables for Wi-Fi, DHCP, US
Wi-Fi regulatory settings, `en_US.UTF-8`, and `America/Los_Angeles`. Hostname is
not a documented first-boot preset variable; instead, they create the
one-time `/root/provisioning.sh` hook, which runs `hostnamectl` after the first
successful login. The Bash
generator validates the mount by checking for an `etc` directory, creates the
preset with restrictive permissions, and uses mode `600`. The provisioning
hook is executable and uses mode `700`. The PowerShell
generator uses a secure prompt for passwords while prompting, but the generated
file necessarily contains plaintext values because Armbian requires them.

Keep both files private, do not commit them, and delete them immediately after
the first successful SSH login. They are temporary bootstrap material, not
general configuration files.

## Continue to first boot

Insert the prepared card, connect the board to power, and allow several minutes
for Armbian's first boot. Continue with [First boot and Wi-Fi](01-first-boot-wifi.md).

Keep UART/serial access available before optional GPU installation. The PVR
module has a safety-critical delayed-load requirement; a successful SD-card
boot alone is not evidence that the GPU stack is compatible.

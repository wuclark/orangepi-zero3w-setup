# Fresh Armbian installation from Windows

For the full SD-card, Wi-Fi, and first-boot process on Windows, Linux, or
macOS, start with [Prepare the SD card](../guide/00-prepare-sd-card.md), then
[First boot and Wi-Fi](../guide/01-first-boot-wifi.md). This
page covers the later vendor archive and PVR installation phase.

> The preferred method now transfers `pvr-userspace.tar.gz` and optional
> `vpu-userspace.tar.gz` unchanged. Run `windows/Copy-VendorArchives.ps1`, then
> `./armbian-startup.sh`. See [the archive workflow](../optional/gpu/archive-workflow.md). The
> extracted-tree procedure below remains as a legacy/debug alternative.

This guide covers the complete workflow when the PowerVR userspace has already
been extracted on a Windows PC and the Orange Pi has a fresh Armbian Debian 13
installation.

## Prerequisites

On Windows:

- PowerShell 5.1 or PowerShell 7
- Windows OpenSSH Client (`ssh.exe` and `scp.exe`)
- `tar.exe`, included with current Windows versions
- The extracted vendor tree containing `usr/lib` and `usr/local/lib`

On the Orange Pi:

- Armbian Debian 13 arm64
- Network connectivity and working SSH
- The matching `6.6.98-vendor-sun60iw2` kernel
- This repository at `/home/orangepi/orangepi-zero3w-setup`

## 1. Copy the repository to the board

From Windows PowerShell, either clone it directly on the board over SSH or copy
the downloaded repository folder. For a GitHub repository:

```powershell
ssh orangepi@BOARD_IP "git clone https://github.com/wuclark/orangepi-zero3w-setup.git"
```

## 2. Transfer the generated vendor archives (recommended)

Open PowerShell in the repository folder on Windows:

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\windows\Copy-VendorArchives.ps1 `
  -SourceDirectory "C:\Users\YOUR-NAME\Downloads\gpu-vpu-output" `
  -BoardHost "BOARD_IP"
```

The source directory must contain `pvr-userspace.tar.gz`. The optional
`vpu-userspace.tar.gz` will be copied when present. Both are uploaded unchanged:

```text
/home/orangepi/orangepi-zero3w-setup/vendor-files
```

For a different SSH username or repository location:

```powershell
.\windows\Copy-VendorArchives.ps1 `
  -SourceDirectory "D:\A733\gpu-vpu-output" `
  -BoardHost "192.168.1.80" `
  -SshUser "orangepi" `
  -RemoteRepoPath "/home/orangepi/orangepi-zero3w-setup"
```

For a manually extracted tree, the legacy `Copy-PvrVendorRoot.ps1` workflow is
still supported through `install.sh --vendor-root DIR`, but it is no longer the
recommended Windows path.

## 3. Run the documented Armbian setup

```bash
ssh orangepi@BOARD_IP
cd ~/orangepi-zero3w-setup
chmod +x armbian-startup.sh install.sh scripts/*.sh
./armbian-startup.sh
```

The script validates the transferred tree before changing the system. It may
prompt first for the sudo password and then for an x11vnc password. Its complete
output is saved under `gpu-bringup-logs/`.

## 4. Reboot and verify

```bash
sudo reboot
```

Wait approximately 60 seconds. The delay is intentional: loading the vendor
module too early was observed to cause kernel instability.

Reconnect and run:

```bash
cd ~/orangepi-zero3w-setup
./scripts/verify.sh
```

Connect a VNC viewer to:

```text
BOARD_IP:5900
```

Test Vulkan presentation inside display `:0`:

```bash
DISPLAY=:0 \
LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/lib \
VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json \
vkcube
```

## Troubleshooting

- `Vendor root not found`: rerun the PowerShell transfer and confirm its remote
  repository path matches the repository used on the board.
- `Missing transferred vendor file`: the selected Windows source is incomplete
  or points one directory too high.
- `Matching kernel headers are not installed`: install the header package for
  the exact running kernel. The vendor image often provides it under `/opt`.
- VNC does not connect immediately after boot: wait for the 30-second GPU load
  plus LightDM startup, then check `systemctl status x11vnc lightdm`.
- Full diagnostics: `sudo ./scripts/collect-diagnostics.sh`.

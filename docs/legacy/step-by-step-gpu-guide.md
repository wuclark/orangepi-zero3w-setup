# Orange Pi Zero 3W: detailed optional GPU guide

> This is the optional GPU reference-stack guide. For the general CLI-only
> board setup, start with [First boot and Wi-Fi](../guide/01-first-boot-wifi.md), then
> add desktop and remote access separately.

> The preferred input is now `pvr-userspace.tar.gz`, with optional
> `vpu-userspace.tar.gz`. Follow [the archive workflow](../optional/gpu/archive-workflow.md).
> Any later `vendor-root` instructions are the legacy/debug alternative.

The desktop layer supports separate X11 profiles (`openbox`, `xfce`, `i3`,
`icewm`, and `fluxbox`) and experimental Wayland profiles (`sway` and `labwc`). Install a
profile with `setup.sh desktop`, then switch installed profiles with
`sudo orangepi-session set PROFILE --reboot`. The proven GPU evidence in this
guide applies to the X11/LightDM path only; a Wayland login requires separate
board evidence.

This guide reproduces hardware-accelerated Vulkan, OpenGL ES, X11 presentation,
and x11vnc on an Orange Pi Zero 3W with the Allwinner A733 and PowerVR
BXM-4-64 GPU.

## Known-good target

| Component | Verified value |
|---|---|
| Board | Orange Pi Zero 3W / Allwinner A733 |
| Architecture | arm64 / AArch64 |
| Distribution | Armbian Debian 13 Trixie |
| Kernel | `6.6.98-vendor-sun60iw2` |
| PowerVR DDK | `24.2.6603887` |
| GPU BVNC | `36.56.104.183` |
| Vulkan device | PowerVR B-Series BXM-4-64 MC1 |
| Firmware | `rgx.fw.36.56.104.183`, `rgx.sh.36.56.104.183` |

Do not use a module built for a different kernel. The installer compares the
module's `vermagic` with the running kernel before installing it.

## How the working graphics path is arranged

The board has separate display and rendering DRM devices:

| Device | Job |
|---|---|
| `/dev/dri/card0` | Sunxi display controller and HDMI scanout |
| `/dev/dri/card1` | PowerVR DRM device |
| `/dev/dri/renderD128` | PowerVR rendering node |

Xorg must use `card0` for its screen. The vendor Mesa KMSRO integration connects
that screen to the PowerVR render node. Selecting `card1` as the Xorg display
device fails because it is not the HDMI scanout controller.

## Step 1: prepare fresh Armbian

Flash and boot the matching Armbian Debian 13 image. Complete the initial user
setup, connect networking, and confirm SSH access.

On the board:

```bash
uname -a
uname -m
cat /etc/os-release
ip -br address
```

Expected architecture:

```text
aarch64
```

The reference kernel is:

```text
6.6.98-vendor-sun60iw2
```

Update ordinary packages before starting:

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

## Step 2: place this repository on the board

From the Orange Pi:

```bash
sudo apt update
sudo apt install -y git

cd ~
git clone https://github.com/YOUR-NAME/orangepi-zero3w-setup.git
cd orangepi-zero3w-setup
```

If using the downloadable ZIP instead:

```bash
sudo apt install -y unzip
unzip orangepi-zero3w-setup.zip
cd orangepi-zero3w-setup
```

## Step 3: identify the generated archives on Windows

The PowerVR files cannot be redistributed by this project. Generate the
matching outputs legally with `OrangePiZero3W-GPU-VPU`. The selected directory
should contain:

```text
gpu-vpu-output/
├── pvr-userspace.tar.gz
└── vpu-userspace.tar.gz
```

## Step 4: transfer the archives unchanged from Windows

Open PowerShell in your local copy of this repository:

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\windows\Copy-VendorArchives.ps1 `
  -SourceDirectory "C:\Users\YOUR-NAME\Downloads\gpu-vpu-output" `
  -BoardHost "192.168.1.80" `
  -SshUser "orangepi" `
  -RemoteRepoPath "/home/orangepi/orangepi-zero3w-setup"
```

The script uploads the existing archives without extracting or repackaging them.
This preserves Linux symlinks, modes, filenames, and layout.

The underlying transfer pattern is:

```powershell
$Board = "orangepi@192.168.1.80"
ssh.exe $Board "mkdir -p ~/orangepi-zero3w-setup/vendor-files"
scp.exe .\pvr-userspace.tar.gz "${Board}:~/orangepi-zero3w-setup/vendor-files/"
scp.exe .\vpu-userspace.tar.gz "${Board}:~/orangepi-zero3w-setup/vendor-files/"
```

Prefer the repository's full PowerShell script because it adds validation and
error handling around these commands.

## Step 5: validate and stage the archives on Armbian

```bash
cd ~/orangepi-zero3w-setup

stage=$(mktemp -d)
./scripts/prepare-vendor-archives.sh \
  --pvr-tarball vendor-files/pvr-userspace.tar.gz \
  --vpu-tarball vendor-files/vpu-userspace.tar.gz \
  --output "$stage"
```

The validator rejects unsafe archive paths/links and incomplete PVR archives.
The installer repeats this check in a fresh private staging directory.

## Step 6: run the documented startup installer

```bash
chmod +x armbian-startup.sh install.sh scripts/*.sh
./armbian-startup.sh
```

This wrapper saves all output under `gpu-bringup-logs/`. It calls the all-in-one
installer using the transferred tree and the invoking user.

To reboot automatically only after successful installation:

```bash
./armbian-startup.sh --reboot
```

To omit VNC:

```bash
./armbian-startup.sh --without-x11vnc
```

## Step 7: understand what the installer changes

### Kernel module

If `vendor-files/pvrsrvkm.ko` is absent, the installer builds it from the Orange
Pi vendor kernel source. It requires matching headers at:

```text
/lib/modules/$(uname -r)/build
```

When the image provides a header package under `/opt`, the installer attempts
to install it. The final module is rejected unless this succeeds:

```bash
modinfo -F vermagic vendor-files/pvrsrvkm.ko
uname -r
```

### Safe delayed module startup

The installed service intentionally waits 30 seconds:

```ini
[Unit]
Description=Delayed PowerVR GPU kernel module loading
ConditionPathExists=/opt/pvrsrvkm.ko
After=multi-user.target
Before=display-manager.service lightdm.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=/bin/sh -c '/usr/sbin/lsmod | /usr/bin/grep -q "^pvrsrvkm " || /sbin/insmod /opt/pvrsrvkm.ko'
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
```

Early automatic udev/module loading is deliberately avoided because it was
unstable on the reference vendor kernel.

### Isolated userspace

The proprietary runtime is kept out of Debian's core library directories:

```text
/opt/pvr-ddk-24.2/lib
/opt/pvr-ddk-24.2/mesa/lib
/opt/pvr-ddk-24.2/mesa/dri
/opt/pvr-ddk-24.2/vulkan
```

Debian continues to provide the system Vulkan loader. The ICD manifest points
to the isolated driver:

```json
{
  "file_format_version": "1.0.0",
  "ICD": {
    "library_path": "/opt/pvr-ddk-24.2/lib/libVK_IMG.so",
    "api_version": "1.3.277"
  }
}
```

### Xorg scanout selection

The installed Xorg configuration pins the display controller:

```conf
Section "Device"
    Identifier "Sunxi Display"
    Driver "modesetting"
    Option "kmsdev" "/dev/dri/card0"
EndSection
```

The Xorg wrapper injects only the vendor Mesa/DRI environment required by the
display server:

```sh
#!/bin/sh
export LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/mesa/lib:/opt/pvr-ddk-24.2/lib
export LIBGL_DRIVERS_PATH=/opt/pvr-ddk-24.2/mesa/dri
exec /usr/lib/xorg/Xorg "$@"
```

### Headless HDMI

The default forced mode is appended to `/boot/armbianEnv.txt`:

```text
video=HDMI-A-1:1920x1080@60D
```

Use `sudo ./install.sh --no-force-video` when a real display and EDID are always
present.

### x11vnc

The VNC service mirrors the real hardware-backed display `:0`:

```ini
[Unit]
Description=x11vnc for the DRM-backed Xorg desktop
After=lightdm.service network-online.target
Wants=lightdm.service network-online.target

[Service]
Type=simple
User=orangepi
Group=orangepi
ExecStartPre=/bin/sh -c 'until test -S /tmp/.X11-unix/X0; do sleep 1; done'
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -forever -shared -rfbauth /home/orangepi/.vnc/passwd -rfbport 5900 -noxdamage -repeat
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical.target
```

Do not expose TCP 5900 directly to the internet. Use a trusted LAN, firewall,
SSH tunnel, WireGuard, or another VPN.

## Step 8: reboot and allow delayed startup

```bash
sudo reboot
```

Wait approximately 60 seconds before testing. Thirty seconds are intentionally
spent waiting before module insertion; LightDM and the desktop start after it.

## Step 9: verify every layer

### Service and device nodes

```bash
systemctl status pvr-late-load.service lightdm.service x11vnc.service \
  --no-pager -l

lsmod | grep pvrsrvkm
ls -l /dev/dri
```

Expected DRM nodes include:

```text
card0
card1
renderD128
```

### Firmware

```bash
sudo dmesg | grep -Ei 'PVR_K|RGX|pvrsrvkm' | tail -n 100
```

Look for matching BVNC and firmware messages:

```text
Read BVNC 36.56.104.183 from HW device registers
RGX Firmware image 'rgx.fw.36.56.104.183' loaded
Shader binary image 'rgx.sh.36.56.104.183' loaded
```

### Headless Vulkan

```bash
env -u DISPLAY \
LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/lib \
VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json \
vulkaninfo --summary
```

Expected device:

```text
PowerVR B-Series BXM-4-64 MC1
```

### X11 and DRI3

```bash
DISPLAY=:0 xdpyinfo | grep -E 'dimensions|DRI2|DRI3|Present'
DISPLAY=:0 xrandr
```

### Vulkan presentation

```bash
DISPLAY=:0 \
LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/lib \
VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json \
vkcube
```

The successful result is a hardware-rendered spinning cube.

### Automated verification

```bash
cd ~/orangepi-zero3w-setup
./scripts/verify.sh
```

## Step 10: connect through VNC

Connect the VNC viewer to:

```text
BOARD_IP:5900
```

Confirm the service locally if needed:

```bash
systemctl status x11vnc --no-pager -l
ss -lntp | grep ':5900'
```

An SSH tunnel is safer across untrusted networks:

```powershell
ssh -L 5900:127.0.0.1:5900 orangepi@BOARD_IP
```

Then point the VNC viewer at `127.0.0.1:5900`.

## Recovery

If the desktop fails, SSH or serial access should remain available.

Disable the graphical target temporarily:

```bash
sudo systemctl disable --now lightdm x11vnc
sudo systemctl set-default multi-user.target
```

Collect diagnostics:

```bash
cd ~/orangepi-zero3w-setup
sudo ./scripts/collect-diagnostics.sh
```

Disable the installed integration without deleting the diagnostic logs:

```bash
sudo ./scripts/uninstall.sh
```

Installer backups are stored below:

```text
/var/backups/orangepi-zero3w-setup/
```

## Updating the repository

Before updating a working board, preserve its known-good state:

```bash
./scripts/verify.sh | tee gpu-bringup-logs/before-update.txt
git status
git pull --ff-only
./tests/static-checks.sh
```

Do not replace the PowerVR userspace, firmware, or kernel module independently.
They form a matched DDK/BVNC/kernel stack.

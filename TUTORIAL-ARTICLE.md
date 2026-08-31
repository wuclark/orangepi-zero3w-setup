# We made the Orange Pi Zero 3W’s PowerVR GPU render a Vulkan cube on Armbian

> This is an optional GPU case study, not the default board setup. The general
> project starts CLI-only and does not install a GUI, VNC, or run `apt update`.

**Updated reproducibility note:** transfer the generated `pvr-userspace.tar.gz`
and optional `vpu-userspace.tar.gz` unchanged. The installer validates and
stages them on Linux, avoiding Windows damage to symlinks or permissions. See
`docs/optional/gpu/archive-workflow.md`; extracted `pvr-stage` trees are now a legacy option.

The Orange Pi Zero 3W is a tiny Allwinner A733 board with a PowerVR B-Series
BXM-4-64 GPU. The hardware is capable, but on a clean Armbian Debian 13 system,
getting the proprietary PowerVR stack, X11 presentation, and a headless VNC
desktop working together is not a normal `apt install` exercise.

The final result of this bring-up was:

```text
Vulkan device: PowerVR B-Series BXM-4-64 MC1
Vulkan API: 1.3.277
Driver: PowerVR B-Series Vulkan Driver 24.2@6603887
OpenGL ES: PowerVR ES 3.2
X11: DRI2, DRI3, Present
Remote desktop: x11vnc
Presentation test: spinning hardware-rendered vkcube
```

This article explains what made it work and how to reproduce it using the
orangepi-zero3w-setup repository.

## The central problem: rendering and display are different devices

After loading the PowerVR module, the board exposes:

```text
/dev/dri/card0       Sunxi display/HDMI controller
/dev/dri/card1       PowerVR DRM device
/dev/dri/renderD128  PowerVR render node
```

That separation explains several misleading failures. Vulkan can enumerate the
PowerVR GPU without X11, yet `vkcube` can still fail because Xorg lacks DRI3.
Conversely, Xorg can display a desktop through `card0` while OpenGL silently
falls back to llvmpipe.

The working design keeps `card0` as Xorg’s scanout device and uses the vendor
Mesa KMSRO/DRI layer to reach `renderD128` for acceleration.

## Why this repository does not include the proprietary binaries

orangepi-zero3w-setup is source-only. It contains installers, configuration,
validation, documentation, and build automation. Users supply a legally
obtained matching PowerVR filesystem.

The verified combination is:

```text
Kernel: 6.6.98-vendor-sun60iw2
DDK: 24.2.6603887
BVNC: 36.56.104.183
Firmware: rgx.fw.36.56.104.183 and rgx.sh.36.56.104.183
```

Mixing versions is a poor gamble. The kernel module, firmware, Vulkan ICD,
services libraries, shader compiler, GLES libraries, Mesa WSI library, and DRI
driver should be treated as a matched unit.

## Moving the generated archives from Windows

Use the upstream outputs `pvr-userspace.tar.gz` and `vpu-userspace.tar.gz`
unchanged. This preserves Linux metadata and avoids a fragile Windows extraction.

The repository includes `windows/Copy-VendorArchives.ps1`:

```powershell
Set-ExecutionPolicy -Scope Process Bypass

.\windows\Copy-VendorArchives.ps1 `
  -SourceDirectory "C:\Users\YOUR-NAME\Downloads\gpu-vpu-output" `
  -BoardHost "192.168.1.80" `
  -SshUser "orangepi" `
  -RemoteRepoPath "/home/orangepi/orangepi-zero3w-setup"
```

Conceptually, it performs these operations:

```powershell
$Board = "orangepi@192.168.1.80"
ssh.exe $Board "mkdir -p ~/orangepi-zero3w-setup/vendor-files"
scp.exe .\pvr-userspace.tar.gz "${Board}:~/orangepi-zero3w-setup/vendor-files/"
scp.exe .\vpu-userspace.tar.gz "${Board}:~/orangepi-zero3w-setup/vendor-files/"
```

On Armbian, the installer validates paths and link targets, extracts privately,
then copies only known files into isolated `/opt` locations.

## One command on fresh Armbian

Once the archives exist under `vendor-files/`:

```bash
cd ~/orangepi-zero3w-setup
chmod +x armbian-startup.sh install.sh scripts/*.sh
./armbian-startup.sh
```

The documented wrapper checks architecture and vendor contents, starts the
all-in-one installer, and records everything to a timestamped log:

```bash
mkdir -p gpu-bringup-logs
LOG_FILE="gpu-bringup-logs/install-$(date -u +%Y%m%dT%H%M%SZ).log"

sudo ./install.sh \
  --pvr-tarball ./vendor-files/pvr-userspace.tar.gz \
  --vpu-tarball ./vendor-files/vpu-userspace.tar.gz \
  --module ./vendor-files/pvrsrvkm.ko \
  --user orangepi \
  2>&1 | tee "$LOG_FILE"
```

The real wrapper preserves the installer’s exit code through the `tee` pipeline
and will not reboot after a failure.

## Building the matching kernel module

When no module is supplied, the installer builds one against the running
kernel. Before accepting it, the scripts compare:

```bash
uname -r
modinfo -F name vendor-files/pvrsrvkm.ko
modinfo -F vermagic vendor-files/pvrsrvkm.ko
```

The expected module name is `pvrsrvkm`, and the beginning of `vermagic` must
match `uname -r`. This check prevents a convenient-looking but dangerous module
from another kernel from being installed.

## The critical delayed-load service

The working board did not safely tolerate normal early automatic loading. The
solution was an explicit late service ordered before LightDM:

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

LightDM waits for this service. The desktop therefore appears later than usual,
but the sequence is deterministic:

```text
boot → wait 30 seconds → insert pvrsrvkm → create renderD128 → start Xorg
```

## Keeping the proprietary stack isolated

Rather than replace Debian’s Vulkan loader and Mesa packages globally, the
project installs the vendor pieces under `/opt`:

```text
/opt/pvr-ddk-24.2/lib
/opt/pvr-ddk-24.2/mesa/lib
/opt/pvr-ddk-24.2/mesa/dri
```

The Vulkan manifest is small and explicit:

```json
{
  "file_format_version": "1.0.0",
  "ICD": {
    "library_path": "/opt/pvr-ddk-24.2/lib/libVK_IMG.so",
    "api_version": "1.3.277"
  }
}
```

This allows Debian’s normal `libvulkan.so.1` to discover the proprietary ICD
without overwriting the system loader.

## The libraries that finally made X11 presentation work

Core Vulkan enumeration succeeded before X11 presentation did. `vkcube` still
reported that DRI3 support was unavailable. The complete vendor path required:

```text
libpvr_mesa_wsi.so
pvr_dri.so
libGLESv1_CM_PVR_MESA.so
libGLESv2_PVR_MESA.so
vendor libEGL.so
vendor libgbm.so
vendor libglapi.so
```

The vendor DRI binary exposes several driver entry points. The installation
creates the aliases expected by different Mesa/Xorg lookup paths:

```bash
cd /opt/pvr-ddk-24.2/mesa/dri
ln -sfn pvr_dri.so sunxi-drm_dri.so
ln -sfn pvr_dri.so sunxi_drm_dri.so
ln -sfn pvr_dri.so libdril_dri.so
ln -sfn pvr_dri.so swrast_dri.so
ln -sfn pvr_dri.so kms_swrast_dri.so
```

## Pinning Xorg to the display controller

Xorg sees both DRM cards and can choose incorrectly. The solution is explicit:

```conf
Section "Device"
    Identifier "Sunxi Display"
    Driver "modesetting"
    Option "kmsdev" "/dev/dri/card0"
EndSection
```

The Xorg process is launched through a wrapper:

```sh
#!/bin/sh
export LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/mesa/lib:/opt/pvr-ddk-24.2/lib
export LIBGL_DRIVERS_PATH=/opt/pvr-ddk-24.2/mesa/dri
exec /usr/lib/xorg/Xorg "$@"
```

This matters because setting these vendor paths globally would affect unrelated
applications and make recovery harder.

## Creating a headless but real X11 desktop

x11vnc mirrors an existing Xorg display; it does not create one. With no monitor
attached, the kernel still needs a usable HDMI mode. The default is:

```text
video=HDMI-A-1:1920x1080@60D
```

LightDM autologins to Openbox on display `:0`, and x11vnc waits until its socket
exists:

```ini
ExecStartPre=/bin/sh -c 'until test -S /tmp/.X11-unix/X0; do sleep 1; done'
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -forever -shared -rfbauth /home/orangepi/.vnc/passwd -rfbport 5900 -noxdamage -repeat
```

For remote use outside a trusted LAN, tunnel VNC over SSH:

```powershell
ssh -L 5900:127.0.0.1:5900 orangepi@BOARD_IP
```

The VNC viewer then connects to `127.0.0.1:5900`.

## Proving that acceleration is real

After rebooting and waiting approximately one minute:

```bash
lsmod | grep pvrsrvkm
ls -l /dev/dri
```

The firmware messages should match the hardware BVNC:

```bash
sudo dmesg | grep -Ei 'PVR_K|RGX|pvrsrvkm' | tail -n 100
```

Test Vulkan without a display first:

```bash
env -u DISPLAY \
LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/lib \
VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json \
vulkaninfo --summary
```

The output must name the physical PowerVR GPU, not llvmpipe or lavapipe:

```text
deviceName = PowerVR B-Series BXM-4-64 MC1
driverInfo = 24.2@6603887
```

Then verify X11 extensions:

```bash
DISPLAY=:0 xdpyinfo | grep -E 'DRI2|DRI3|Present'
```

Finally test presentation:

```bash
DISPLAY=:0 \
LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/lib \
VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json \
vkcube
```

That spinning cube closes the loop: application → Vulkan loader → proprietary
ICD → PowerVR kernel driver → render node → DRI3 → Sunxi scanout.

## What this project teaches

The difficult part was not any single missing package. It was recognizing that
five layers had to agree:

1. the exact kernel and out-of-tree module;
2. the GPU BVNC and firmware;
3. the proprietary Vulkan/GLES services libraries;
4. Mesa KMSRO/DRI integration between the render and display devices;
5. Xorg startup ordering and headless presentation.

orangepi-zero3w-setup turns that working state into a guarded, logged, reversible
installation instead of a collection of commands buried in shell history.

The full terminal-oriented procedure is in
`docs/legacy/step-by-step-gpu-guide.md`, while `docs/reference/troubleshooting.md` covers common
failure signatures and recovery.

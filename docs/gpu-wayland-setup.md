# PowerVR GPU and hardware-accelerated Wayland

This guide records the current Weston bring-up path on the Orange Pi Zero 3W
(Allwinner A733) with Armbian/Debian Trixie and the vendor
`6.6.98-vendor-sun60iw2` kernel. It assumes the matching PowerVR userspace has
already been grafted under `/opt/pvr-ddk-24.2`, `pvrsrvkm` is loaded, and the
kernel module is bound to the PowerVR DRM device. This repository's existing
archive workflow handles that graft; the new scripts only wire up and verify
the runtime.

The expected hardware identity is PowerVR B-Series BXM-4-64, DDK
`24.2.6603887`, BVNC `36.56.104.183`. Do not install a kernel module from a
different A733 image. Verify the prerequisite before proceeding:

```bash
lsmod | grep pvrsrvkm
readlink -f /sys/class/drm/card1/device/driver
```

## Quick setup

Run these on the board. The first script updates the linker cache and GLVND;
the second installs a tty1-bound Weston service; the third is a repeatable
diagnostic check:

```bash
sudo ./scripts/10-fix-pvr-linker-and-glvnd.sh
sudo ./scripts/20-install-weston-service.sh
./scripts/99-verify.sh
```

Set `PVR_DDK_DIR=/opt/another-ddk` before any script when the DDK is installed
under a different directory. Set `WESTON_USER=name` for a different login
user when installing the service.

Equivalent Make targets are available on the board:

```bash
sudo make board-gpu-wayland-setup
make board-gpu-wayland-verify
```

The setup target disables LightDM, x11vnc, and the tty1 getty so they cannot
compete with Weston for the DRM device. It does not install proprietary files
or rebuild the kernel module. It fails if EGL/GLES or the latest Weston log
falls back to llvmpipe or softpipe. Use the existing LightDM enable/unmask path
when returning to an X11 desktop.

## Debugging history and fixes

### 1. The vendor Mesa library directory was absent from ld.so

The original linker configuration listed only `/opt/pvr-ddk-24.2/lib`, while
`libEGL.so.1`, `libGLESv2.so.2`, and `libglapi.so.0` live under
`/opt/pvr-ddk-24.2/mesa/lib`. `10-fix-pvr-linker-and-glvnd.sh` adds that exact
directory once and runs `/sbin/ldconfig`.

### 2. EGL/GLES depended on vendor libglapi

The missing `libglapi.so.0` dependency made the vendor EGL/GLES stack fail to
resolve and allowed software fallbacks. The matched `mesa/lib` directory must
be visible to the linker as a unit.

### 3. GLVND had no PowerVR EGL vendor JSON

The DDK supplies a Vulkan ICD JSON but not an EGL vendor JSON. The linker fix
creates `/usr/share/glvnd/egl_vendor.d/00_pvr.json` pointing at the vendor
`libEGL.so.1`. The numeric prefix makes it tried early, but GLVND selection
still depends on which vendor initializes successfully; the prefix alone does
not guarantee selection.

### 4. System Mesa and vendor Mesa DRI ABIs were mixed

Using Debian's EGL loader with the vendor `pvr_dri.so` silently produced
llvmpipe because the DRI driver was built against a different Mesa internal
ABI. All EGL/GLES/glapi tests therefore use both:

```text
LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/mesa/lib
LIBGL_DRIVERS_PATH=/opt/pvr-ddk-24.2/mesa/dri
```

The helper and Weston wrapper scope these paths to the tested process. A valid
test must report `PowerVR B-Series BXM-4-64`, not merely initialize EGL.

### 5. Weston needed a real seat and console

Launching Weston interactively over SSH initially failed or behaved
inconsistently because an SSH pty is not a real logind seat. The installed
service uses `PAMName=login`, `/dev/tty1`, and standard tty input, and disables
`getty@tty1.service` so Weston owns that console.

### 6. Environment variables did not reliably survive dbus-run-session

A service restart once reported PowerVR and another reported softpipe even
though the unit's `Environment=` lines were unchanged. The unit retains those
lines as defense in depth, but `weston-pvr-launch.sh` exports the variables in
the process that directly execs Weston. This wrapper is the effective fix.

### 7. The connected display has malformed EDID data

The test display reports a CTA-861 conformity error. HDMI hotplug/reconnect
can make the vendor `sunxi-hdmi` driver fail to reparse modes, followed by
invalid atomic commits and loss of output. This is a BSP/display quirk, not a
PowerVR linker fix. If required, add a fixed mode in `/etc/xdg/weston/weston.ini`:

```ini
[output]
name=HDMI-A-1
mode=1024x600
```

Use the mode appropriate to the connected panel. This is an optional workaround
and must be tested with the actual display and reboot/reconnect procedure.

## Verification after updates

Run:

```bash
make board-gpu-wayland-verify
```

or:

```bash
./scripts/99-verify.sh
```

The verifier checks `pvrsrvkm`, the card1 driver binding, Vulkan, the linker
cache, the GLVND JSON, EGL/GLES, the Weston service, and the last `GL renderer`
entry in the service log. It reports HDMI connection status as informational.

The current known limitation is native PowerVR Wayland client EGL: the
shipped vendor `libEGL.so` contains `Wayland platform not built`, so
`weston-simple-egl` fails under the vendor client stack even though the Weston
compositor itself renders with PowerVR. This guide does not claim native
PowerVR Wayland client or Wayland Vulkan presentation support until a licensed
DDK with a working Wayland client platform is tested.

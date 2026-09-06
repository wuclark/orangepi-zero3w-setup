# Vendor sources and provenance

orangepi-zero3w-setup does not redistribute PowerVR firmware or proprietary user-space
libraries. Each user must obtain those files from an image or package they are
legally permitted to use.

## Kernel source

The PowerVR kernel module is built from Orange Pi's vendor kernel tree:

- Repository: <https://github.com/wuclark/linux-orangepi>
- Branch: `orange-pi-6.6-sun60iw2`
- Module directory: `bsp/modules/gpu/img-bxm/linux/rogue_km`

This maintained fork currently contains the complete branch history needed by
the module build. The build script uses it by default; pass `--repo` to use a
different mirror.

Use `scripts/build-pvrsrvkm.sh` on the target board. It builds against the
currently running kernel headers and refuses to publish a module whose vermagic
does not match that kernel.

## Matching proprietary user space

The verified stack is Imagination DDK `24.2.6603887`, GPU BVNC
`36.56.104.183`. A known source is the Radxa Cubie A7S Debian image used by the
community hybrid-image project below:

- Extraction project: <https://github.com/Incipiens/OrangePiZero3W-GPU-VPU>
- Radxa image project: <https://github.com/cuihuir/radxa-a7z-debian12>
- Referenced archive: `radxa-a733_bullseye_kde_r2.output_512.img.xz`
- Referenced archive SHA-256:
  `1b5604fed61647ab1b510f24af5968477e8a7a361430aa0864efbed7b5fe6ca2`

This repository's `scripts/extract-vendor-userspace.sh` produces
`pvr-userspace.tar.gz`, `vpu-userspace.tar.gz`, and the experimental
`npu-userspace.tar.gz`. The external project remains a provenance/reference
source for the Radxa extraction layout. Copy generated archives unchanged into
`vendor-files/` and run:

```bash
sudo ./install.sh
```

The installer validates archive paths and link targets, stages privately, and
checks the expected DDK/BVNC file set before changing the active runtime. The
older `install-userspace.sh --vendor-root` interface remains a lower-level
debugging tool.

## Related bring-up work

- Debian 13 kernel-module research and delayed-load approach:
  <https://github.com/Haidegger22/orangepi-zero3w-gpu-pcie>
- A733 PowerVR + FEX bring-up notes, dual-Mesa split, and kernel-deadlock
  finding for a live GPU compositor:
  <https://github.com/ayiejosh/a733-powervr-fex>
- Allwinner BSP notes including Linux 6.18 `drm/imagination` + Mesa main
  Wayland observations:
  <https://github.com/DockSeed/allwinner-bsp>

## Wayland-enabled userspace candidates (research only, no support claim)

The verified stack in this repository (`24.2.6603887` / `36.56.104.183`)
ships a `libEGL.so` containing `Wayland platform not built`, and its Vulkan
ICD advertises XCB/XLIB surfaces but not `VK_KHR_wayland_surface`. The
Weston compositor itself can render on PowerVR, but native PowerVR Wayland
clients (`weston-simple-egl`) fail. See
[acceleration status](../../reference/acceleration-status.md) and
[Wayland setup](../../gpu-wayland-setup.md). What is needed is a different
build of the same DDK/BVNC userspace with the Wayland EGL client platform
compiled in, obtained from a source the user is legally permitted to use.
Do not broaden the support matrix until the evidence gate in `AGENTS.md`
is met.

### Where to look legally

This repository redistributes no proprietary binaries. Obtain each
candidate from an image or package you are legally permitted to use, and
read its shipped license terms first.

1. Radxa A7Z Debian 12 project (`cuihuir/radxa-a7z-debian12`):
   <https://github.com/cuihuir/radxa-a7z-debian12>
   Claims `a733-pvr-gpu 24.2.6603887+gpu8` with PowerVR-accelerated
   KWin/Plasma Wayland, EGL/GBM, and packaged XWayland 24.1.6 GLES glamor
   on kernel `5.15.147-21.1-a733`. It is the most promising candidate to
   inspect for a Wayland-enabled `libEGL.so`. Its kernel module targets
   `5.15.147-21.1-a733` and must not be installed on the reference
   `6.6.98-vendor-sun60iw2` board; compare userspace only.
2. Same-silicon provenance already used by this repository:
   <https://github.com/Incipiens/OrangePiZero3W-GPU-VPU>
   Re-scan newer Radxa `6.6.x-aw2511` images and the Radxa A733 vendor
   packages (`img-bxm-dkms`, `xserver-xorg-img-bxm`) referenced by
   <https://github.com/ayiejosh/a733-powervr-fex> for a Wayland-enabled
   `libEGL.so` build. That FEX bring-up repo also records why a live
   GPU-composited desktop on `pvrsrvkm` can deadlock the kernel, so test
   off-screen before any compositor test.
3. Licensed DDK source path: Imagination proprietary DDKs remain available
   to IP licensees and are developed separately from the open-source
   driver (see
   <https://blog.imaginationtech.com/open-source-graphics-driver-adds-vulkan-1.2-support-and-additional-gpus>).
   Request an A733 Wayland-enabled EGL build, or licensed DDK sources to
   rebuild that component with Wayland enabled, through the Orange Pi /
   Radxa / Allwinner channel. There is no public download to link here.
   This is currently the only path that could give native PowerVR
   Wayland clients on this board: a different build of the same
   `24.2.6603887` / `36.56.104.183` userspace with the Wayland EGL
   client platform compiled in. The open-source driver below cannot do
   this for BXM-4-64.
4. Open-source driver (not available for A733 BXM-4-64): upstream
   kernel `drm/imagination` plus Mesa plus firmware, documented at
   <https://developer.imaginationtech.com/solutions/open-source-gpu-driver/>.
   On the current `6.6.98-vendor-sun60iw2` vendor kernel this stack
   cannot bind to the Zero 3W GPU; do not install it here. Track it
   only for a future lift of the closed-driver ceiling.

   | GPU | Upstream status (Oct 2025 blog + Jul 2026 developer page) | Zero 3W relevance |
   | --- | --- | --- |
   | IMG AXE-1-16 (e.g. TI AM62/BeaglePlay) | Supported: Mesa 25.3 Vulkan 1.0 conformant, kernel 6.16+ | Try open-source here, not on A733 |
   | IMG BXS-4-64 (e.g. TI AM68/SK-AM68) | Supported: Mesa 25.3 Vulkan 1.0 conformant Aug 2025, kernel 6.16+ | Try open-source here, not on A733 |
   | IMG BXM-4-64 / BVNC 36.56.104.183 (A733/Zero 3W) | Not listed as supported; Vulkan 1.2 submissions were planned for early 2026 with Volcanic preparation only | Keep closed DDK 24.2.6603887; open-source gives no Wayland path here |
   | Kernel/firmware delivery | Linux 6.16 upstream, additional core in 6.18; firmware at <https://gitlab.freedesktop.org/imagination/linux-firmware/-/tree/powervr/powervr>; Mesa at <https://gitlab.freedesktop.org/mesa/mesa/> | Incompatible with the 6.6 vendor kernel ABI and delayed-`pvrsrvkm` boot order |

   Linux 6.18 `drm/imagination` plus Mesa main is reported to give
   `vulkaninfo`, Sway GLES, and on-screen `vkmark` on other SoCs
   (see <https://github.com/DockSeed/allwinner-bsp>), not on A733.

### How to compare a candidate without mixing modules

Stage every candidate privately first; never extract an untrusted archive
over `/` (use `scripts/prepare-vendor-archives.sh` staging). Before any
board install, compare dependencies, DRI/WSI files, firmware, and ABI
identifiers against the reference stack:

```bash
strings candidate/usr/lib/libEGL* | grep -i "Wayland platform"
strings candidate/usr/lib/libEGL* | grep -i wayland
diff <(strings /opt/pvr-ddk-24.2/lib/libEGL.so.1) <(strings candidate/usr/lib/libEGL.so.1) | head
```

Confirm the kernel side still matches this board and refuse on mismatch:

```bash
sudo ./scripts/board-gpu-abi-check.sh
uname -r  # must remain 6.6.98-vendor-sun60iw2
modinfo -F vermagic /opt/pvrsrvkm.ko
```

Keep Sunxi `card0` as scanout and PowerVR `card1`/`renderD128` as render;
replace no system Mesa globally and create no global EGL symlinks as a
test. Keep serial/UART recovery available.

### How to test native client and Vulkan Wayland presentation

Run from a local HDMI console with UART recovery available, after the
documented delayed `pvrsrvkm` load. Do not use `sudo` for graphical tests
inside the Wayland session.

```bash
echo "$XDG_SESSION_TYPE $WAYLAND_DISPLAY $XDG_RUNTIME_DIR"
wayland-info  # expect zwp_linux_dmabuf_v1 when the compositor runs
DISPLAY=:0 ./scripts/run-pvr-app.sh eglinfo -B  # must report PowerVR B-Series BXM-4-64
./scripts/run-pvr-app.sh weston-simple-egl  # native client probe; fails on current stack
vulkaninfo | grep -F VK_KHR_wayland_surface  # required before claiming Wayland Vulkan presentation
```

A successful Wayland login alone is not acceleration evidence. Record
complete evidence with `scripts/collect-diagnostics.sh` and keep
proprietary files and sanitized results out of Git, per the evidence gate.

### Native client sample

Use the open-source PowerVR Native SDK Wayland sample once a candidate
userspace is staged:

- Sample source:
  <https://github.com/powervr-graphics/Native_SDK/blob/master/examples/OpenGLES/01_HelloAPI/OpenGLESHelloAPI_LinuxWayland.cpp>
- SDK base:
  <https://github.com/powervr-graphics/Native_SDK/>
- SDK introduction (notes that API system libraries come from the
  platform provider):
  <https://docs.imgtec.com/sdk-documentation/html/introduction.html>
- Wayland build thread (`cmake -DPVR_WINDOW_SYSTEM=Wayland`):
  <https://forums.imgtec.com/t/powervr-sdk-wayland-egl-sample-availability/4253>

```bash
mkdir build && cd build
cmake .. -DPVR_WINDOW_SYSTEM=Wayland
cmake --build ./
```

The SDK provides the client code only; `libEGL`/`libGLESv2`/ICD behavior
still comes from the staged vendor userspace under test.

Read the license terms shipped with the source images and packages. The MIT
license in this repository covers only this repository's original scripts and
documentation; it does not relicense third-party binaries or source code.

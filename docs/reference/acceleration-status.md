# A733 acceleration status

This is the current bring-up snapshot for the Orange Pi Zero 3W test board.
It records observed behavior without expanding the supported matrix. Formal
support still requires the evidence gate in `AGENTS.md`.

## Board and baseline

```text
Board: Orange Pi Zero 3W / Allwinner A733
Kernel: 6.6.98-vendor-sun60iw2
GPU DDK: 24.2.6603887
GPU BVNC: 36.56.104.183
Display: HDMI-A-1, 1024x600 at 60 Hz
```

The current userspace is under `/opt/pvr-ddk-24.2` and is selected only
through `scripts/run-pvr-app.sh`. Delayed `pvrsrvkm` loading and separation of
Sunxi display `card0` from the PowerVR render node remain required.

## Observed results

- Weston 14 starts with the DRM backend and initializes HDMI.
- Weston uses PowerVR when launched through the isolated environment:

  ```text
  GL vendor: Imagination Technologies
  GL renderer: PowerVR B-Series BXM-4-64
  GL version: OpenGL ES 3.2 build 24.2@6603887
  ```

- `wayland-info` connects to Weston and reports `HDMI-A-1` and
  `zwp_linux_dmabuf_v1` version 3.
- `eglinfo -B` through the helper reports PowerVR for GBM, surfaceless, and
  device probes.
- Plain Mesa `weston-simple-egl` runs at about 60 FPS using llvmpipe.

## Current blocker

The vendor EGL client test fails:

```text
weston-simple-egl: ../clients/simple-egl.c:232: init_egl:
Assertion `ret == EGL_TRUE' failed.
```

The vendor `libEGL.so` contains `Wayland platform not built`. The public A733
package investigated uses the same DDK/BVNC, but its `libEGL.so` is
byte-for-byte identical to the current file. Its included kernel module also
targets `5.15.147-21.1-a733` and must not be installed on this board.

| Path | Result |
| --- | --- |
| Weston compositor + PowerVR GBM | Works |
| PowerVR EGL/GLES GBM/surfaceless probes | Works |
| Native PowerVR Wayland EGL client | Blocked: Wayland platform is not built |
| Mesa Wayland client | Works, software-rendered |
| Wayland Vulkan presentation | Not claimed |

## What is needed

1. Obtain a legally usable ARM/A733 DDK userspace with Wayland client support,
   matching DDK/BVNC and kernel ABI; or obtain licensed DDK sources and rebuild
   that component with Wayland enabled.
2. Stage candidates privately and compare dependencies, DRI/WSI files,
   firmware, and ABI identifiers before board installation.
3. Test a native PowerVR Wayland client, visible HDMI presentation, Vulkan
   surface support, and repeated reboot/recovery behavior.
4. Record complete evidence with `scripts/collect-diagnostics.sh`; keep
   proprietary files and sanitized results out of Git.

Do not mix a kernel module or firmware from another A733 image into this
kernel, replace system Mesa, or create global EGL symlinks as a test.

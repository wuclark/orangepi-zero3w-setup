# Support matrix

This matrix records the tested boundary for the current project. It is not a
promise that every feature works on every A733 board or kernel.

| Component | Current reference | Status | Evidence/boundary |
| --- | --- | --- | --- |
| Board | Orange Pi Zero 3W, A733, 12 GB | Verified | Real-board reports identify `xunlong,orangepi-zero3w` and `sun60iw2p1`. |
| OS | Armbian 26.8.x, Debian 13 Trixie | Verified | Board diagnostics report Armbian/Debian 13. |
| Kernel | `6.6.98-vendor-sun60iw2` | Verified | ABI check, module vermagic, and board validation. |
| GPU/Vulkan | DDK 24.2, BXM-4-64 MC1, BVNC `36.56.104.183` | Verified | Vulkan summary, zero-error compute benchmark, and visibly presented `vkcube` over HDMI. |
| EGL/GLES | DDK 24.2 | Verified | Headless/surfaceless EGL and board validation. |
| X11 DRI2/DRI3/Present | Xorg/LightDM | Verified with session access | Wrong user or missing X11 authorization can make checks fail. |
| X11 GLX | Mesa GLX | Known limitation | Uses llvmpipe; Vulkan/EGL PowerVR remain functional. |
| VPU | Cedar/libcedarc | Verified | H.264 and H.265 hardware GStreamer decode tests on the reference board. |
| NPU | VIPLite 2.0.3.2, ACUITY `ubuntu-npu:v2.0.10.2` | Verified smoke, candidate golden, and lenet/yolov5/resnet50 ACUITY goldens | Pinned `network_binary.nb` executes; custom-LUT candidate matches; all three generated goldens match top-5 on the reference board (2026-09-08 validation). A golden for the pinned sample remains unavailable. |
| USB-C DisplayPort | Board connector/driver path | Runtime-dependent | Use `board-display-status` and record whether `DP-1` is connected. |
| HDMI audio | `allwinnerhdmi`, ALSA device 0 | Playback path verified | Actual sound requires a connected HDMI sink. |
| RetroArch | Debian package with isolated Vulkan launcher | Verified | PowerVR GPU, X11 Vulkan context, swapchain, and core checks. |
| Native PowerVR Wayland client (`weston-simple-egl`) | DDK 24.2 `libEGL.so` reports `Wayland platform not built` | Known limitation, research only | Compositor renders on PowerVR; native client needs a Wayland-enabled build of the same DDK/BVNC, see `docs/optional/gpu/vendor-sources.md`. |
| Open-source Mesa `drm/imagination` driver | BXM-4-64 not listed (only AXE-1-16, BXS-4-64 on kernel 6.16+/6.18) | Not supported on this board/kernel | Developer page and Vulkan 1.2 blog tracked in `docs/optional/gpu/vendor-sources.md`; keep closed DDK 24.2.6603887. |

New support claims require sanitized diagnostics containing kernel release,
module vermagic, DDK build, BVNC, DRM nodes, DRI3 output,
`vulkaninfo --summary`, and a successful presentation test.

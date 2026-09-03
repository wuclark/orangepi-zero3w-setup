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
| NPU | VIPLite 2.0.3.2 | Verified smoke plus candidate golden | Pinned `network_binary.nb` executes successfully; the SDK custom-LUT candidate matches its supplied golden. A golden for the pinned sample remains unavailable. |
| USB-C DisplayPort | Board connector/driver path | Runtime-dependent | Use `board-display-status` and record whether `DP-1` is connected. |
| HDMI audio | `allwinnerhdmi`, ALSA device 0 | Playback path verified | Actual sound requires a connected HDMI sink. |
| RetroArch | Debian package with isolated Vulkan launcher | Verified | PowerVR GPU, X11 Vulkan context, swapchain, and core checks. |

New support claims require sanitized diagnostics containing kernel release,
module vermagic, DDK build, BVNC, DRM nodes, DRI3 output,
`vulkaninfo --summary`, and a successful presentation test.

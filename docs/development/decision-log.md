# Decision log

| Decision | Reason |
| --- | --- |
| Keep the base image CLI-only | Avoid silent desktop, VNC, GPU, or reboot side effects. |
| Load `pvrsrvkm` through a delayed service | The vendor module can destabilize early boot; delay preserves a recoverable boot path. |
| Keep vendor files in private archives | Proprietary files and redistribution rights are not source code. |
| Use extraction allowlists | Explicit paths reduce accidental mixing and make manifests reviewable. |
| Keep `orange-pi-6.6-sun60iw2` source separate | Kernel/module ABI compatibility is board-specific. |
| Isolate PVR libraries in scoped launchers | Global library precedence caused `libOpenCL.so.1` conflicts and crashes. |
| Treat Vulkan/EGL as the GPU success boundary | They work reliably while X11 GLX remains llvmpipe. |
| Use direct ALSA for RetroArch | The board has a known HDMI device and does not require PulseAudio/PipeWire. |
| Prefer Snes9x/BSNES Mercury Performance | Accuracy mode is heavier on this board. |
| Use official AArch64 cores with cache/hash reuse | Debian may lack advanced cores; official artifacts are safer than random binaries. |
| Make stability testing headless and continuous by default | Endurance testing should not require a display and zero interval exercises sustained load. |
| Keep storage testing opt-in | SD writes can wear or stress a device and require deliberate consent. |

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
| Defer `board-config` menu to v1.1 | Ship v1.0 on the proven X11 reference stack; the menu is UX convenience, not a correctness gate. |
| Prefer Snes9x/BSNES Mercury Performance | Accuracy mode is heavier on this board. |
| Use official AArch64 cores with cache/hash reuse | Debian may lack advanced cores; official artifacts are safer than random binaries. |
| Make stability testing headless and continuous by default | Endurance testing should not require a display and zero interval exercises sustained load. |
| Keep storage testing opt-in | SD writes can wear or stress a device and require deliberate consent. |
| Enable PCIe HATs with a Gen2 + PD22/PD23 overlay via `user_overlays` | The root port was already enabled; the driver missed external power/reset GPIOs and Gen3 retraining failed, so the overlay adds both and cold boot applies them. |
| Use numeric GPIO flags in the PCIe overlay | Plain `dtc` skips the C preprocessor, so the `dt-bindings` include form fails to parse. |
| Offer MATE and KDE Plasma as experimental X11 profiles only | They reuse the tested Sunxi `card0`/PowerVR X11 path and LightDM autologin, but their weight and compositor demands are unproven on this board; package/configuration support only until presentation and reboot evidence exists. |
| Offer LXQt as an experimental lightweight X11 profile | `lxqt-core` with `startlxqt` on the same LightDM/X11 path; light footprint suits small boards but still needs presentation and reboot evidence before any support claim. |
| Offer LXDE as an experimental very-light X11 profile | `lxde-core` with `startlxde` on the same LightDM/X11 path; minimal GTK footprint suits 1 GB boards but still needs presentation and reboot evidence before any support claim. |
| Offer Budgie as an experimental GNOME-stack X11 profile | `budgie-desktop` with `budgie-desktop` on the same LightDM/X11 path; heavier GNOME dependencies suit larger boards only and still need presentation and reboot evidence before any support claim. |
| Offer Cinnamon as an experimental X11 profile under LightDM | `cinnamon-core` with `cinnamon-session` on the same LightDM/X11 path with no `gdm3`; compositing demands are unproven on the PowerVR path, so package/configuration support only until presentation and reboot evidence exists. |
| Pin window managers explicitly under --no-install-recommends | `kwin-x11` is only a Recommends of `plasma-desktop` and no WM ships in `lxqt-core` deps, so both profiles name their window manager outright; a WM-less session cannot manage windows or complete logout (seen on hardware, matches Debian bug #1110436). |
| Run GNOME Shell on Xorg under LightDM without gdm3 | Install `gnome-session` + `gnome-shell` à la carte and skip the `gnome-core` metapackage that hard-depends on `gdm3`; mutter ships inside Shell so no WM pin is needed, but the profile stays experimental until board evidence exists (expect software rendering). |
| Offer GNOME Flashback as the light GNOME X11 profile | `gnome-session-flashback` hard-depends on metacity, panel, and settings daemon, so no pin or `gdm3` is involved; traditional panel UI suits small boards far better than Shell, with the same experimental gate. |
| Offer Compiz as a standalone llvmpipe compositing session | `compiz` metapackage plus `compiz-plugins-extra` and `tint2` panel on the X11 path; eye candy renders through `llvmpipe`, so slideshow-grade performance is documented up front, and the guide mandates the `ccsm` first-run plugin set that makes the session interactive. |
| Right-click single-touch panels with a watching (non-grabbing) uinput daemon | X11-only helpers cannot run on Wayland sessions, and grabbing/re-emitting touch would risk killing all touch on daemon failure; observing read-only and injecting BTN_RIGHT keeps plain touch working with or without the daemon. Offer both `hold` and `tap-hold` gestures so long-press drag/select stays available. |

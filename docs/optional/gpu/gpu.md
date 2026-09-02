# Optional GPU acceleration

The PowerVR DDK and out-of-tree `pvrsrvkm` module are optional and supported
only on the reference Armbian Debian 13 vendor kernel. Read the existing
[archive workflow](archive-workflow.md), [architecture](../../reference/architecture.md), and
[troubleshooting guide](../../reference/troubleshooting.md) before installation.

```bash
sudo ./setup.sh gpu
```

The GPU command uses the existing apt cache. Add `--update` only when you
explicitly want to refresh package metadata:

```bash
sudo ./setup.sh gpu --update
```

This path is safety-sensitive: the tested kernel requires delayed module
loading. Do not shorten or replace that ordering without a board reboot test,
UART access, and a recovery plan.

## Launching EGL/GLES applications

Do not set the vendor library paths globally for every application. Use the
repository helper for programs that should use the PowerVR EGL/GLES stack:

```bash
DISPLAY=:0 ./scripts/run-pvr-app.sh eglinfo -B
DISPLAY=:0 ./scripts/run-pvr-app.sh vkcube
```

The helper sets `LD_LIBRARY_PATH` and `LIBGL_DRIVERS_PATH` for only the child
application. A plain `glxinfo -B` may still report Mesa `llvmpipe`; that is the
separate desktop GLX path and is not evidence that Vulkan or EGL/GLES failed.

The optional compute benchmark has an explicit dependency target:

```bash
sudo make board-gpu-compute-deps
```

It installs `g++`, `libvulkan-dev`, and either `glslc` or `glslangValidator`
using the existing apt cache. It does not run `apt update`.

For WSL/Ubuntu, install and run the CPU Vulkan baseline separately:

```bash
sudo apt update
make wsl-vulkan-compute-deps
make wsl-vulkan-compute-test
```

This target forces Mesa Lavapipe, so its timings are not Orange Pi GPU
measurements. It is useful for validating benchmark correctness before running
the same source on the board.

After installing the dependencies, run the headless compute benchmark:

```bash
sudo make board-gpu-compute-test
```

It compiles the repository’s vector-add and matrix-multiply shaders, checks
their results against CPU references, and records GPU timestamp durations in
`/var/log/orangepi-zero3w-setup/vulkan-compute-benchmark.txt`.

## Wayland validation

Wayland is not active in the default LightDM/Openbox session. Test it from a
local HDMI console, with UART recovery available, after installing a Wayland
profile:

```bash
sudo ./setup.sh desktop --profile labwc
sudo orangepi-session set labwc --reboot
```

Inside the Wayland session, do not use `sudo` for graphical tests:

```bash
echo "$XDG_SESSION_TYPE $WAYLAND_DISPLAY $XDG_RUNTIME_DIR"
wayland-info
./scripts/run-pvr-app.sh eglinfo -B
```

On the current Orange Pi test board, Weston itself can use the PowerVR
renderer, but the vendor EGL client test fails because the shipped EGL build
contains `Wayland platform not built`. See the [acceleration status](../../reference/acceleration-status.md)
for the exact boundary. Separately check the Vulkan surface capability:

```bash
vulkaninfo | grep -F VK_KHR_wayland_surface
```

The current verified Vulkan output advertises X11 XCB/XLIB surfaces but not
`VK_KHR_wayland_surface`, so Wayland Vulkan presentation is not currently
claimed. A successful Wayland login alone is not acceleration evidence.

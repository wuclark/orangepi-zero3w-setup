# Troubleshooting

## Vulkan reports no GPUs after reboot

Check:

```bash
systemctl status pvr-late-load.service --no-pager -l
lsmod | grep pvrsrvkm
ls -l /dev/dri
```

During the intentional 30-second delay, only `card0` exists and LightDM remains inactive. Wait until the service exits successfully.

## `modprobe: Module pvrsrvkm not found`

This project deliberately loads `/opt/pvrsrvkm.ko` using `insmod`. Do not install the module through `modules-load.d` on the reference vendor kernel; early loading was associated with kernel panic.

## Xorg loops with `no screens found`

If Xorg chooses `card1`, it reports:

```text
KMS doesn't support dumb interface
KMS setup failed
```

Confirm `/etc/X11/xorg.conf.d/10-sunxi-primary.conf` pins Xorg to `/dev/dri/card0`.

## `vkcube: No DRI3 support detected`

Check:

```bash
DISPLAY=:0 xdpyinfo | grep -E 'DRI2|DRI3|Present'
```

If DRI3 is absent, inspect `/var/log/Xorg.0.log` and `/var/log/lightdm/x-0.log`. Confirm the Xorg wrapper is active and that the PowerVR GLES libraries exist in `/opt/pvr-ddk-24.2/lib`.

## EGL falls back to softpipe

Missing files commonly responsible:

```text
libGLESv1_CM_PVR_MESA.so
libGLESv2_PVR_MESA.so
```

Use `scripts/verify.sh` and check all `ldd` results.

Run EGL/GLES applications through the isolated helper so the vendor libraries
are selected:

```bash
DISPLAY=:0 ./scripts/run-pvr-app.sh eglinfo -B
```

If this reports PowerVR while plain `eglinfo` reports llvmpipe, the hardware
path is present and only the application environment was missing. Desktop
GLX may still remain on llvmpipe.

## Testing Wayland

The default session is X11. Test `labwc` or `sway` from the local HDMI console
after selecting the profile and rebooting. In the Wayland session check
`wayland-info` and run `./scripts/run-pvr-app.sh eglinfo -B`. Also check
`vulkaninfo` for `VK_KHR_wayland_surface`; without that extension, do not claim
Wayland Vulkan presentation support.

## X11 shows 1024x600 instead of forced 1080p

EDID preferred modes override the forced connector mode after Xorg starts. Use:

```bash
DISPLAY=:0 xrandr --output HDMI-1 --mode 1920x1080 --rate 60
```

The reference 7-inch MPI7010 display correctly prefers 1024x600.

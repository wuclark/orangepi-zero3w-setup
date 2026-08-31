# Architecture

## DRM split

The A733 vendor stack separates display and rendering:

```text
Applications (Vulkan / GLES)
          |
PowerVR userspace DDK 24.2
          |
PowerVR renderD128 + card1
          |
DMA-BUF / Mesa KMSRO / DRI3
          |
Sunxi card0 display controller
          |
HDMI / Xorg / x11vnc
```

The PVR node has no display connectors and does not provide the dumb-buffer interface expected by Xorg's primary modesetting screen. The Sunxi DRM node has connectors but no 3D engine. The vendor Mesa integration joins them.

## Boot ordering

The reference vendor kernel can panic if `pvrsrvkm` is inserted too early through udev or `modules-load.d`. The service therefore waits 30 seconds and completes before LightDM starts:

```text
multi-user.target
       |
30-second safety delay
       |
insmod /opt/pvrsrvkm.ko
       |
card1 + renderD128
       |
LightDM starts Xorg
       |
Xorg sees both DRM devices
```

## Isolated userspace

Debian retains its Vulkan loader and system Mesa installation. PowerVR libraries live under `/opt/pvr-ddk-24.2`. Xorg receives the vendor EGL/GBM/DRI paths through a wrapper so other system processes are not globally forced onto the vendor Mesa build.


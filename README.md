# Orange Pi Zero 3W Setup

Modular setup guide and scripts for the Orange Pi Zero 3W (Allwinner A733).
The first release targets Armbian Debian 13 with the vendor
`6.6.98-vendor-sun60iw2` kernel. The Orange Pi Zero 3 / H618 is not supported.

The base path is deliberately CLI-only. It does not run `apt update`, upgrade
packages, install a GUI, expose VNC, or reboot. Optional desktop, remote-access,
GPU, VPU, and NPU layers are installed separately.

## Quick start

For a new SD card, follow [Prepare the SD card](docs/guide/00-prepare-sd-card.md),
then [First boot and Wi-Fi](docs/guide/01-first-boot-wifi.md). After SSH works:

```bash
sudo ./setup.sh base
sudo ./setup.sh packages
```

For a username-independent SSH and maintenance foundation, run the core layer
from the setup directory:

```bash
sudo ./setup.sh core
sudo ./setup.sh sources
```

The setup remains installed at `/opt/orangepi-zero3w-setup`; the selected
login user's `~/orangepi-zero3w-setup` path is only a symlink to that location.

When preparing the card, you may pre-copy the unchanged GPU and optional VPU
archives into the repository's `vendor-files/` directory; the preparation
guide documents the layout and permissions. Otherwise transfer them after boot
with the Windows helper.

For a fully prepared card, the Docker workflow can create two reproducible
derived images: `prepare-preloaded-image-docker.sh` embeds the repository and
GPU/VPU/NPU archives, then `prepare-firstboot-image-docker.sh` adds the local
first-boot preset and provisioning hook. The base and preloaded images remain
unchanged; the final image contains credentials and must stay outside Git.
The final SD image is named with its UTC creation timestamp, such as
`*-preloaded-firstboot-20260901T143012Z.img`. Before writing it, run
`make validate` to verify the checksum and partition table.
The same sequence can be driven from WSL2/Linux with `make image`; existing
archives and derived images are reused automatically. `make test` runs the
host checks. An existing credential-bearing final image requires
`REBUILD=1 make image`, which preserves the old image before rebuilding.
Run `make preset` first when you need to interactively create the local
first-boot files; it never runs implicitly as part of `make image`.
For a completely fresh build that cleans generated outputs, prompts for the
preset, builds both image stages, and validates the result, run `make newsd`.
The normal `make summary` output redacts credentials; use
`make show-unredacted` only for local troubleshooting.
Run `make help` for the complete SD-card-to-board handoff sequence.
Use `make clean` to remove generated archives, derived images, metadata, and
local first-boot files while preserving source/base images under `work/images/`.

The first-boot generator asks for a hostname and creates a one-time
`/root/provisioning.sh` hook to apply it after the first successful login.
Armbian's preset file itself contains only documented first-boot variables.

Package installation uses the existing apt cache. To explicitly refresh it:

```bash
sudo ./setup.sh packages --update
```

Choose a GUI only when wanted. Available desktop profiles include X11 sessions
(`openbox`, `xfce`, `i3`, `icewm`, `fluxbox`) and Wayland sessions
(`sway`, `labwc`):

```bash
sudo ./setup.sh desktop --profile openbox
```

Docker and Docker Compose are optional. Choose option `4` in
`sudo ./setup.sh packages`; see the [base-system guide](docs/guide/02-base-system.md#docker-and-docker-compose)
for post-install group and verification steps.

Remote access is a separate choice. SSH tunneling is the default:

```bash
sudo ./setup.sh remote --backend x11vnc
```

See [the SSH tunneling guide](docs/remote/ssh-tunneling.md) for Windows TightVNC
Viewer instructions.

## Guide

- [Prepare the SD card](docs/guide/00-prepare-sd-card.md)
- [First boot and Wi-Fi](docs/guide/01-first-boot-wifi.md)
- [Base system](docs/guide/02-base-system.md)
- [Desktop sessions](docs/guide/03-desktop-sessions.md)
- [Remote access](docs/guide/04-remote-access.md)
- [Recovery and reset](docs/guide/05-recovery.md)
- [Optional GPU](docs/optional/gpu/gpu.md)
- [Optional VPU](docs/optional/vpu.md)
- [Optional NPU](docs/optional/npu.md)
- [A733 source and provenance map](docs/reference/source-provenance.md)

## Optional PowerVR reference stack

The proven PowerVR stack remains available as an optional, safety-sensitive
module. It is not required to boot, use Wi-Fi, run the CLI, or install a basic
desktop. Its supported evidence remains narrowly limited to:

This project reproduces a confirmed working stack:

- PowerVR kernel module: `pvrsrvkm 24.2.6603887`
- GPU/BVNC: `PowerVR B-Series BXM-4-64 MC1`, `36.56.104.183`
- Vulkan: hardware Vulkan 1.3 through Debian's Vulkan loader
- OpenGL ES: PowerVR OpenGL ES 3.2
- X11: Sunxi `card0` scanout plus PowerVR `renderD128`, DRI3 and Present
- Remote desktop: optional `x11vnc`

## Important scope

The scripts intentionally do **not** redistribute proprietary Imagination/PowerVR binaries. You must provide legally generated userspace archives containing the matching DDK files and build or provide `pvrsrvkm.ko` for your exact kernel.

The known-good target is deliberately narrow:

```text
Board: Orange Pi Zero 3W / Allwinner A733
Kernel: 6.6.98-vendor-sun60iw2
DDK: 24.2.6603887
BVNC: 36.56.104.183
Firmware: rgx.fw.36.56.104.183 + rgx.sh.36.56.104.183
OS: Armbian Debian 13 (Trixie), arm64
```

Do not force installation on another kernel unless you understand the risks. An incompatible out-of-tree GPU module can crash the kernel.

To install the reference GPU stack after the base setup, place the legally
generated PowerVR archive in `vendor-files/pvr-userspace.tar.gz` and run:

```bash
sudo ./setup.sh gpu
```

For a fresh board with the generated archives stored on Windows, follow
[Fresh Armbian installation from Windows](docs/legacy/fresh-armbian-install.md). It uses:

- `windows/Copy-VendorArchives.ps1` on Windows; then
- `./armbian-startup.sh` on the Orange Pi.

For a completely headless board, begin with [Prepare the SD card](docs/guide/00-prepare-sd-card.md).
The base image installs no extra software; `scripts/armbian-provision.sh`
offers an explicit opt-in menu after SSH is working.

Additional documentation:

- [Development roadmap](ROADMAP.md)
- [Testing workflows](tests/README.md)
- [Detailed step-by-step GPU guide](docs/legacy/step-by-step-gpu-guide.md)
- [Preferred userspace archive workflow](docs/optional/gpu/archive-workflow.md)
- [Publishable tutorial article](TUTORIAL-ARTICLE.md)
- [Architecture explanation](docs/reference/architecture.md)
- [Hardware references](docs/reference/hardware.md)
- [Troubleshooting and recovery](docs/reference/troubleshooting.md)

On the board, validate and install one acceleration layer at a time with
`scripts/board-acceleration-workflow.sh`. It records checks, installation
results, reboot requirements, and evidence under
`/var/log/orangepi-zero3w-setup/`.
The equivalent Make targets are `board-gpu-*`, `board-vpu-*`, and
`board-npu-precheck`/`board-npu-install`/`board-npu-verify`. When `work/images/ai-sdk.tar.gz` is
available, `make newsd` also places a selected A733 NPU test bundle in the
image; the full SDK remains outside the image.
Prechecks may report expected missing-layer warnings but still record a
successful baseline; verification steps fail when required checks are absent.
The VPU install also installs the Cedar configuration and GStreamer parser
plugins; `board-vpu-generate-videos` creates local synthetic 720p/1080p
H.264/H.265 samples, and `board-vpu-verify` uses the generated 720p samples
for headless hardware decode tests, falling back to cached downloads if they
are absent. Re-run only those media tests with `make board-vpu-decode-test`.
The individual generated fixtures can be fetched from a pinned GitHub Release
with `make board-vpu-fetch-videos VPU_TESTDATA_TAG=vpu-testdata-v1`.
Use `scripts/run-pvr-app.sh COMMAND` for EGL/GLES applications that must use
the isolated PowerVR environment. Wayland requires a separate local-console
test; see the GPU troubleshooting guide before switching sessions.

The legacy all-in-one GPU command remains available as `install.sh`; it builds
or validates `pvrsrvkm.ko`, installs the matching runtime, and configures the
safe delayed startup. It uses the existing apt cache unless `--update` is
passed. Read the GPU guide before running it.

The lower-level extracted-tree/debug equivalent is:

```bash
cd orangepi-zero3w-setup

sudo ./scripts/armbian-bootstrap.sh \
  --vendor-root "$HOME/pvr-stage" \
  --module /opt/pvrsrvkm.ko \
  --user "$USER"
```

To build only the matching module:

```bash
sudo apt install -y git build-essential bc bison flex libssl-dev libelf-dev
./scripts/build-pvrsrvkm.sh --output ./pvrsrvkm.ko
```

See the [A733 source and provenance map](docs/reference/source-provenance.md) and
[GPU vendor sources](docs/optional/gpu/vendor-sources.md) for the upstream
kernel branch, verified proprietary userspace version, and licensing notes.

The reference GPU bootstrap script:

1. validates the board, architecture, kernel and module `vermagic`;
2. installs Debian runtime packages without replacing Debian's Vulkan loader;
3. copies the matching proprietary runtime into `/opt/pvr-ddk-24.2`;
4. installs matching RGX firmware;
5. creates a delayed `pvrsrvkm` service;
6. configures Xorg to keep Sunxi `card0` as the display device;
7. gives Xorg an isolated PowerVR Mesa/DRI environment;
8. configures the tested X11/LightDM integration;
9. installs verification commands.

Reboot when the installer finishes. The graphical session intentionally starts roughly 30 seconds late so the vendor module is not inserted during the unsafe early-boot period.

After approximately one minute:

```bash
./scripts/verify.sh
```

Test presentation:

```bash
DISPLAY=:0 \
LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/lib \
VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json \
vkcube
```

## x11vnc

The general setup does not install or expose VNC by default. To set it up
separately after an X11 desktop is verified:

```bash
sudo ./scripts/install-x11vnc.sh --user "$USER"
```

Use the SSH tunnel in [ssh-tunneling.md](docs/remote/ssh-tunneling.md), then connect
your Windows viewer to `localhost::5900`. The service mirrors the real Xorg
display; it does not create a separate virtual desktop.

## Vendor root layout

The recommended input is the unchanged archive produced by this repository's
extractor:

```text
vendor-files/pvr-userspace.tar.gz
vendor-files/vpu-userspace.tar.gz  # optional
vendor-files/npu-userspace.tar.gz  # optional experimental
```

The installer validates paths, extracts into a private temporary directory,
and copies only known files into isolated `/opt` locations. It never extracts a
third-party archive over `/`. The legacy `--vendor-root` path remains available
for development. After staging, these paths must exist:

```text
usr/lib/libVK_IMG.so*
usr/lib/libsrv_um.so*
usr/lib/libusc.so*
usr/lib/libufwriter.so*
usr/lib/libglslcompiler.so*
usr/lib/libpvr_dri_support.so*
usr/lib/libGLESv1_CM_PVR_MESA.so*
usr/lib/libGLESv2_PVR_MESA.so*
usr/local/lib/libEGL.so*
usr/local/lib/libgbm.so*
usr/local/lib/libglapi.so*
usr/local/lib/libpvr_mesa_wsi.so*
usr/local/lib/dri/pvr_dri.so
usr/lib/firmware/rgx.fw.36.56.104.183
usr/lib/firmware/rgx.sh.36.56.104.183
```

Some source images place firmware elsewhere. Pass `--firmware-dir PATH` when necessary.

Generate the archives on Linux or WSL2 from verified, mounted source roots:

```bash
./scripts/extract-vendor-userspace-docker.sh
```

See [Userspace archive workflow](docs/optional/gpu/archive-workflow.md) for
the `work/` layout and read-only image-mounting procedure.

Copy the archives unchanged from Windows:

```powershell
.\windows\Copy-VendorArchives.ps1 `
  -SourceDirectory "C:\path\to\orangepi-zero3w-setup\work\vendor-output" `
  -BoardHost "orangepizero3w.local"
```

See [CLI agent development](docs/development/development.md) before continuing with Codex
CLI or Claude Code. `AGENTS.md` is the canonical repository policy; `CLAUDE.md`
points Claude Code to the same rules.

## Why the unusual design?

The board exposes two DRM devices:

| Node | Purpose |
|---|---|
| `/dev/dri/card0` | Sunxi display controller and HDMI scanout |
| `/dev/dri/card1` | PowerVR DRM device |
| `/dev/dri/renderD128` | PowerVR render node |

Xorg must use `card0` as its screen. The vendor Mesa KMSRO/DRI layer connects that display device to the PowerVR render node. If Xorg selects `card1` as primary it fails with `KMS doesn't support dumb interface`; if the PowerVR GLES libraries are missing, DRI initializes and then silently falls back to software.

See [docs/reference/architecture.md](docs/reference/architecture.md) and [docs/reference/troubleshooting.md](docs/reference/troubleshooting.md).

## Safety and recovery

The installer backs up replaced configuration under:

```text
/var/backups/orangepi-zero3w-setup/
```

To disable the stack without deleting the runtime:

```bash
sudo ./scripts/uninstall.sh
```

Keep serial/UART access available while developing kernel graphics support.

## Publishing

Create or use the GitHub repository `orangepi-zero3w-setup`, then from this directory:

```bash
git add .
git commit -m "Initial reproducible PowerVR bring-up"
git branch -M main
git remote add origin https://github.com/wuclark/orangepi-zero3w-setup.git
git push -u origin main
```

## Status

Confirmed on the reference system:

```text
Vulkan device: PowerVR B-Series BXM-4-64 MC1
Vulkan driver: PowerVR B-Series Vulkan Driver 24.2@6603887
OpenGL ES renderer: PowerVR B-Series BXM-4-64
OpenGL ES version: 3.2 build 24.2@6603887
X11 extensions: DRI2, DRI3, Present
vkcube: hardware-rendered and presented successfully
```

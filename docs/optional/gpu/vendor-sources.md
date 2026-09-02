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

Read the license terms shipped with the source images and packages. The MIT
license in this repository covers only this repository's original scripts and
documentation; it does not relicense third-party binaries or source code.

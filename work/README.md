# Local userspace extraction workspace

This directory documents the local-only workspace for vendor images, mounted
root filesystems, and generated userspace archives. The contents are ignored
by Git except for this README and the placeholder files that preserve the
directory layout.

Expected layout:

```text
work/
├── images/                 # verified source images; names are auto-detected
└── vendor-output/          # generated archives and manifests
```

Generate archives from Docker in WSL2 or Linux with:

```bash
./scripts/extract-vendor-userspace-docker.sh
```

Docker mounts the images read-only inside a temporary privileged container. It
recognizes only the pinned Radxa A733 and Orange Pi Zero 3W source-image names,
including their `.img`, `.img.xz`, and `.7z` forms. Other images must be selected
with explicit `GPU_VPU_IMAGE` and `NPU_IMAGE` values and are experimental until
their package paths and output are verified.

Never commit source images, mounted/extracted proprietary files, firmware,
generated archives, manifests containing sensitive data, or kernel modules.

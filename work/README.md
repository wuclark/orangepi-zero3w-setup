# Local userspace extraction workspace

This directory documents the local-only workspace for vendor images, mounted
root filesystems, and generated userspace archives. The contents are ignored
by Git except for this README and the placeholder files that preserve the
directory layout.

Expected layout:

```text
work/
├── images/                 # verified source images
│   └── armbian/
│       └── Armbian_26.8.1_Orangepizero3w_trixie_vendor_6.6.98_minimal.img.xz
└── vendor-output/          # generated archives and manifests

The optional `work/images/ai-sdk.tar.gz` is also used by `make extract` to
create a small, selected `npu-test-assets.tar.gz`; the full SDK is never put
in an image or committed.
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

After generating vendor archives, create a separate preloaded Armbian image:

```bash
./scripts/prepare-preloaded-image-docker.sh
```

The original base image remains unchanged. The output is written beside it as
`Armbian_26.8.1_Orangepizero3w_trixie_vendor_6.6.98_minimal-preloaded.img`.

The exact Armbian basename is required. The preloader accepts the compressed
`.img.xz` or `.img.7z` form, or the uncompressed `.img` form after
decompression; the Radxa and Orange Pi images in the parent `images/`
directory are source images for userspace extraction.

To make a separate final image with first-boot settings, first generate the
Git-ignored `not_logged_in_yet` and `provisioning.sh` files, then run:

```bash
./scripts/prepare-firstboot-image-docker.sh
```

This consumes the `*-preloaded.img`, writes the two files under `/root`, and
creates a `*-preloaded-firstboot.img` beside it. The repository is stored at
`/opt/orangepi-zero3w-setup` and the first-boot hook creates a symlink to it
under the selected user's home directory. Do not commit the preset or the
resulting image because the preset contains credentials.

After those files exist, `make image` runs the complete extraction, image
staging, and pre-write validation sequence. It reuses existing non-empty
archive and preloaded outputs instead of asking the extractor to overwrite
them. Because the final image contains credentials, an existing final image
requires `REBUILD=1 make image`; the old final image is moved aside first.

`make preset` runs the interactive preset generator. It is separate from
`make image` so image builds never prompt for or overwrite credentials.
Use `make newsd` for the complete clean-and-build flow; it preserves the base
images but removes generated outputs before prompting for new credentials.

Use `make clean` to remove generated outputs and local first-boot files while
preserving all source/base images under `work/images/`.

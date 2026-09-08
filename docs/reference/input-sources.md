# Fresh-install input sources

Use this checklist when preparing a new Orange Pi Zero 3W from an empty
checkout. It identifies where each input comes from, where the host workflow
expects it, and which inputs are intentionally not redistributed by this
repository.

The supported reference tuple is an Orange Pi Zero 3W/A733, 12 GB, running
Armbian Debian 13 (Trixie) with the vendor kernel
`6.6.98-vendor-sun60iw2`. Do not substitute a mainline/Current image or a
kernel module from another board. The exact versions and reference hashes are
also recorded in [`manifests/reference-stack.env`](../../manifests/reference-stack.env).

## Required for a basic board

| Input | Where to obtain it | Expected location or use | Verification |
| --- | --- | --- | --- |
| Orange Pi Zero 3W hardware | [Orange Pi](https://www.orangepi.org/) or an authorized reseller | Physical board, reliable 5 V/3 A supply, and microSD card | Confirm the board is Zero 3W/A733 and the 12 GB configuration |
| Armbian vendor image | [Official Orange Pi Zero 3W Armbian page](https://armbian.com/boards/orangepizero3w) | `work/images/armbian/Armbian_26.8.1_Orangepizero3w_trixie_vendor_6.6.98_minimal.img.xz` | Obtain the current published checksum; the filename may change when Armbian republishes it |
| This repository | [`wuclark/orangepi-zero3w-setup`](https://github.com/wuclark/orangepi-zero3w-setup) | Checkout on the Linux/WSL2 host and, after image preparation, `/opt/orangepi-zero3w-setup` on the board | `git status`, then `make validate` for a derived image |

The Armbian image is not included in Git. Keep the downloaded compressed image
unchanged and use `make newsd` or the documented preloaded-image workflow to
create a separate image for the SD card.

## Required for the validated acceleration stack

These source images and outputs contain proprietary or vendor-supplied files.
Obtain and use them only under licenses and access rights that permit your
use. Never commit them, extract an untrusted archive over `/`, or install a
kernel module without checking its `vermagic` against the running kernel.

| Input | Where to obtain it | Expected location | Reference identity / next step |
| --- | --- | --- | --- |
| Radxa A733 GPU/VPU source image | [Radxa Cubie A7S downloads](https://docs.radxa.com/en/cubie/a7s/download) | `work/images/radxa-a733_bullseye_kde_r2.output_512.img.xz` | SHA-256: `e088972c619c8d72e6f89cb699e2459b4b30cc8df160638b5bdc0010069dc3aa`; used by `scripts/extract-vendor-userspace-docker.sh` |
| Orange Pi A733 NPU source image | The authorized Orange Pi vendor image release associated with the A733/Zero 3W; vendor links may change. See [Orange Pi sources and provenance](source-provenance.md#orange-pi-and-allwinner-vendor-sources) | `work/images/Orangepizero3w_1.0.0_ubuntu_jammy_desktop_xfce_linux6.6.98.img` | SHA-256: `af6697c4f158f63ffdf55f5a17453ef3b9b2895f35b2891e6090d28f65faf264`; used by the NPU extraction path |
| AI SDK snapshot | [`wuclark/ai-sdk`](https://github.com/wuclark/ai-sdk) or an authorized local SDK copy | `work/images/ai-sdk.tar.gz` | Needed for NPU test assets and golden generation; do not put the full SDK in the SD image |
| Generated GPU/VPU/NPU archives | Run [`docs/optional/gpu/archive-workflow.md`](../optional/gpu/archive-workflow.md) with the verified source images | `work/vendor-output/{pvr-userspace,vpu-userspace,npu-userspace}.tar.gz` | Verify the generated `*-manifest.sha256` files, then copy unchanged to `vendor-files/` |
| Matching PowerVR kernel source | [`wuclark/linux-orangepi`](https://github.com/wuclark/linux-orangepi) | `build-pvrsrvkm/linux-orangepi` | The image workflow stages it automatically; otherwise run `sudo make board-sources` or `scripts/prepare-kernel-source.sh` |

For a complete preloaded image, the board-side handoff directory should
contain at least:

```text
vendor-files/
├── pvr-userspace.tar.gz
├── vpu-userspace.tar.gz
├── npu-userspace.tar.gz
└── npu-test-assets.tar.gz
```

The NPU test-assets archive is generated from the AI SDK and a LeNet golden by
the host workflow. Run `make npu-golden-lenet` and then `make npu-test-assets`
when it is not already present. The NPU layer is experimental even though the
reference-board validation passed.

## Optional inputs

| Input | Where to obtain it | Used by |
| --- | --- | --- |
| ACUITY/Pegasus Docker image archive | [Allwinner ACUITY archive](https://netstorage.allwinnertech.com:5001/fsdownload/Mh23BhPHq/docker_images_v2.0.x.zip) and [Radxa ACUITY setup guide](https://docs.radxa.com/en/cubie/a7z/app-dev/npu-dev/cubie-acuity-env) | Host-side NPU golden generation; the download is approximately 11 GB and is not needed for ordinary board installation |
| Public ResNet50 ONNX model | `make npu-public-onnx` fetches the pinned Apache-2.0 model and verifies its SHA-256 | `work/images/resnet50-v1-12.onnx`, only for regenerating the ResNet50 golden |
| VPU test fixtures | Generate with `make board-vpu-generate-videos`, or fetch the pinned release with `make board-vpu-fetch-videos` | Board VPU decode and quality tests; not required for normal video playback |
| First-boot credentials | Generate locally with `make preset` or `scripts/create-headless-preset.sh` | Credential-bearing first-boot image; delete the preset after the first successful login |

## Fast preparation check

From the repository root on the host:

```bash
make version
ls -lh work/images/armbian/* work/images/*a733* work/images/ai-sdk.tar.gz 2>/dev/null
./scripts/extract-vendor-userspace-docker.sh
make newsd
make validate
```

If an input is absent, use the table above rather than downloading a random
similarly named image. The extractor refuses ambiguous image matches and
validates the pinned reference hashes when they are supplied through
`GPU_VPU_SHA256` and `NPU_SHA256`.

## Boundaries and non-goals

This page does not provide proprietary binaries, firmware, kernel modules,
credentials, or a universal A733 support claim. It also does not make native
PowerVR Wayland clients or desktop GLX acceleration supported; those limits
are recorded in the [support matrix](support-matrix.md).

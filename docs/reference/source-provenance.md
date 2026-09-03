# A733 source and provenance map

This page records where the setup project's A733 GPU, VPU, NPU, kernel, SDK,
and image knowledge came from. A link in this table is a research or recovery
source; it is not automatically a supported software combination. Hardware
claims still require evidence from the exact Orange Pi board, kernel, module,
firmware, and userspace being tested.

## Maintained `wuclark` repositories

These are the repositories intended to remain available as the project's
maintained copies and working references:

| Repository | Role | Provenance/status |
| --- | --- | --- |
| [`wuclark/orangepi-zero3w-setup`](https://github.com/wuclark/orangepi-zero3w-setup) | This setup, image, installer, and test automation | Maintained project repository |
| [`wuclark/a733_npu_driver`](https://github.com/wuclark/a733_npu_driver) | A733 NPU bring-up, board scripts, NBG/vpm tests, and experiments | Maintained copy/working fork of the A733 NPU bring-up work |
| [`wuclark/ai-sdk`](https://github.com/wuclark/ai-sdk) | VIPLite headers, libraries, examples, models, and conversion assets | Maintained copy of the A733 SDK source used to stage selected image-test assets |
| [`wuclark/radxa-a7a-toolkit`](https://github.com/wuclark/radxa-a7a-toolkit) | Radxa A7A/A733 hardware, GPU, NPU, and utility references | Working fork maintained for this project |
| [`wuclark/a733-powervr-fex`](https://github.com/wuclark/a733-powervr-fex) | PowerVR/FEX and A733 GPU investigation | Working fork maintained for this project |

The setup image builder consumes only the local `work/images/ai-sdk.tar.gz`
snapshot and selected test files. It does not clone these repositories during
an image build, and it does not place proprietary archives or kernel modules in
Git.

After boot, the optional source synchronization command clones the maintained
trees under `/opt/orangepi-zero3w-setup/sources`; the selected user's home only
contains the symlink to the setup directory.

## NPU and SDK origins

| Repository | Role | Provenance/status |
| --- | --- | --- |
| [`petayyyy/a733_npu_driver`](https://github.com/petayyyy/a733_npu_driver) | A733/Vivante VIP9000 NPU bring-up, VIPLite tests, model conversion, and board notes | Independent public reference; its README acknowledges the SDK and kernel sources below |
| [`ZIFENG278/ai-sdk`](https://github.com/ZIFENG278/ai-sdk) | Radxa Cubie A733 VIPLite SDK and examples | Original public SDK reference; the `wuclark` copy is the recovery/maintenance source used by this project |
| [`Rabs9/radxa-cubie-a7a-kernel`](https://github.com/Rabs9/radxa-cubie-a7a-kernel) | Radxa Cubie A7A A733 kernel and hardware tuning | Current Rabs9 repository; the formerly referenced `Rabs9/A733-kernel` path is unavailable |
| [`unnamedwild-ux/frigate_npu_vivante`](https://github.com/unnamedwild-ux/frigate_npu_vivante) | Frigate integration using VIPLite/NBG inference | Community application reference; primarily validated on Radxa A7A |
| [ONNX Runtime VIPLite issue](https://github.com/microsoft/onnxruntime/issues/28244) | VIP9000/VIPLite ecosystem and execution-provider discussion | External compatibility reference, not an implementation used by this setup |

## ACUITY/Pegasus NPU quantization toolchain

Real (non-execution-only) NPU goldens for `lenet`, `yolov5`, and `resnet50`
(see [docs/optional/npu.md](../optional/npu.md#real-acuity-goldens-lenet-yolov5-resnet50))
require the vendor ACUITY/Pegasus quantization toolkit, which is not part of
the `ai-sdk` archive itself (its scripts only reference an external
`$ACUITY_PATH`). The provenance for that toolkit and its prior use:

| Source | Role | Provenance/status |
| --- | --- | --- |
| [Radxa Cubie A7Z ACUITY setup docs](https://docs.radxa.com/en/cubie/a7z/app-dev/npu-dev/cubie-acuity-env) | Documents the A733 ACUITY workflow: Docker image `ubuntu-npu:v2.0.10.1`, `AI_SDK_PLATFORM=a733`, `NPU_VERSION=v3` | Vendor/Radxa reference confirming the toolchain and its intended usage |
| `khalida5/ubuntu-npu:v2.0.10` (Docker Hub) | Public mirror of the ACUITY toolkit Docker image | Community mirror used as the host toolchain; retag locally as `ubuntu-npu:v2.0.10.1` |
| [`wuclark/a733_npu_driver`](https://github.com/wuclark/a733_npu_driver) | Host-side ACUITY conversion scripts (`scripts/host/convert_onnx_to_nbg.sh`, `package_acuity_nbg.py`) and board-validated conversion reports | Maintained working repository this project's `scripts/generate-npu-golden.sh` drives directly; see `reports/g2-acuity-lenet.md` and `reports/g2-acuity-inception-v1.md` for prior board-validated LeNet and Inception v1 conversions on real A733 VIP9000 hardware (including the Orange Pi Zero 3W) |

## Orange Pi and Allwinner vendor sources

| Repository | Role | Provenance/status |
| --- | --- | --- |
| [`wuclark/linux-orangepi`](https://github.com/wuclark/linux-orangepi) | Maintained fork of the Orange Pi vendor Linux kernel, including the `orange-pi-6.6-sun60iw2` branch | Kernel source corresponding to the Orange Pi vendor image; used by the GPU module build path |
| [`orangepi-xunlong/orangepi-build`](https://github.com/orangepi-xunlong/orangepi-build) | Orange Pi image build scripts and kernel configuration | Vendor image-build reference |
| [`orangepi-xunlong/u-boot-orangepi`](https://github.com/orangepi-xunlong/u-boot-orangepi) | Orange Pi bootloader source | Vendor boot-chain reference; not built by this setup |
| [`torvalds/linux`](https://github.com/torvalds/linux) A733 bindings | Mainline Linux device-tree and binding history | Upstream reference; it does not replace the vendor kernel required by the current image |

The running board evidence for this project is based on kernel
`6.6.98-vendor-sun60iw2`. The installed `vipcore.ko`, `cedar-ve`, and device
trees come from the board image/kernel package, not from a repository cloned by
the setup scripts.

The reference board's verified CPU numbering is also recorded: CPUs 0–5 are
the lower-frequency 1.794 GHz cluster and CPUs 6–7 are the higher-frequency
2.002 GHz cluster. This is board evidence, not a universal A733 numbering
guarantee; check `lscpu` before applying affinity settings.

## Radxa and Allwinner BSP sources

| Repository | Role | Provenance/status |
| --- | --- | --- |
| [`radxa/allwinner-bsp`](https://github.com/radxa/allwinner-bsp) | A733 BSP and platform support | Radxa vendor/BSP reference |
| [`radxa/allwinner-target`](https://github.com/radxa/allwinner-target) | A733 target filesystem overlays and vendor userspace layout | Radxa vendor reference; possible source layout for GPU/VPU userspace |
| [`radxa/allwinner-device`](https://github.com/radxa/allwinner-device) | A733 board configuration and device files | Radxa vendor board reference |
| [`radxa-pkg/linux-a733`](https://github.com/radxa-pkg/linux-a733) | Packaged Radxa A733 Linux kernel configuration | Radxa packaging reference, primarily for Cubie boards |
| [`radxa-pkg/aic8800`](https://github.com/radxa-pkg/aic8800) | AIC8800 Wi-Fi/Bluetooth driver packaging | Radxa peripheral-driver reference |
| [`radxa-build/radxa-a733`](https://github.com/radxa-build/radxa-a733) | Radxa A733 image build workflow | Radxa image-build reference |
| [`cuihuir/radxa-a7z-debian12`](https://github.com/cuihuir/radxa-a7z-debian12) | Radxa A7Z Debian image, kernel/GPU packaging, and deployment research | Community Radxa image reference |

## GPU, VPU, and extraction references

| Repository | Role | Provenance/status |
| --- | --- | --- |
| [`Incipiens/OrangePiZero3W-GPU-VPU`](https://github.com/Incipiens/OrangePiZero3W-GPU-VPU) | Orange Pi Zero 3W GPU/VPU extraction and image work | Community extraction reference used to understand Radxa-to-Orange-Pi userspace layout |
| [`Haidegger22/orangepi-zero3w-gpu-pcie`](https://github.com/Haidegger22/orangepi-zero3w-gpu-pcie) | Orange Pi Zero 3W PowerVR, PCIe, and Debian 13 research | Community bring-up reference, including GPU module and boot-order investigations |
| [`ayiejosh/a733-powervr-fex`](https://github.com/ayiejosh/a733-powervr-fex) | A733 PowerVR/FEX experiments | Independent GPU research reference |

The verified PowerVR userspace was extracted from the locally supplied Radxa
image identified in [`manifests/reference-stack.env`](../../manifests/reference-stack.env):

```text
Image: radxa-a733_bullseye_kde_r2.output_512.img.xz
SHA256: e088972c619c8d72e6f89cb699e2459b4b30cc8df160638b5bdc0010069dc3aa
```

The NPU source image recorded by the manifest is:

```text
Image: Orangepizero3w_1.0.0_ubuntu_jammy_desktop_xfce_linux6.6.98.img
SHA256: af6697c4f158f63ffdf55f5a17453ef3b9b2895f35b2891e6090d28f65faf264
```

These images and generated archives are intentionally excluded from Git.
Obtain them only from sources and licenses you are authorized to use.

## Recovery and mirroring

For an archival copy, prefer a mirror clone because it preserves branches,
tags, and other refs:

```bash
mkdir -p ~/git-mirrors
git clone --mirror https://github.com/wuclark/a733_npu_driver.git \
  ~/git-mirrors/a733_npu_driver.git
git clone --mirror https://github.com/wuclark/ai-sdk.git \
  ~/git-mirrors/ai-sdk.git
git clone --mirror https://github.com/Rabs9/radxa-cubie-a7a-kernel.git \
  ~/git-mirrors/radxa-cubie-a7a-kernel.git
```

Use the `wuclark` repositories for project continuity. Keep the independent
repositories above as separate mirrors where possible; do not silently merge
their histories or imply that their board-specific binaries are interchangeable.

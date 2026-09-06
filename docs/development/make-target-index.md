# Make-target index

This index maps public Make targets to their implementation and side effects.
Run `make help` for the complete command list; update this file when adding a
new public target or changing a target's boundary.

| Target family | Main implementation | Runs on | Purpose and side effects |
| --- | --- | --- | --- |
| `extract`, `preloaded`, `firstboot`, `image`, `newsd` | `scripts/extract-*`, `scripts/prepare-*` | Host/WSL2 | Build derived images and private vendor archives under ignored `work/`. |
| `preset`, `summary`, `validate` | `scripts/create-headless-preset.sh`, `show-build-summary.sh`, `validate-image-before-write.sh` | Host | Create local credential-bearing inputs, summarize, and validate images. |
| `board-base`, `board-packages`, `board-core`, `board-sources` | `setup.sh` and `scripts/setup-*` | Board | Install the foundation and optional A733 source checkout. |
| `board-gpu-*` | `scripts/board-acceleration-workflow.sh` | Board | Precheck, install, ABI-check, benchmark, and verify PowerVR. |
| `board-vpu-*` | `scripts/board-acceleration-workflow.sh`, `test-vpu-decode.sh` | Board | Install and validate Cedar/libcedarc and H.264/H.265 decode. |
| `board-npu-*` | `scripts/board-acceleration-workflow.sh`, `test-npu.sh` | Board | Install and validate VIPLite userspace and the smoke test. |
| `npu-golden-candidate` | `scripts/stage-npu-golden-candidate.sh` | Host | Stage the SDK custom-LUT NBG/input/golden bundle under ignored `work/`. |
| `npu-driver-source` | Make target using `git clone` | Host | Clone or reuse the public `a733_npu_driver` checkout under `NPU_DRIVER_REPO`; never overwrites an existing path. |
| `npu-acuity-image-load` | Make target using `unzip` and `docker load` | Host | Stream the nested official ACUITY ZIP contents through a private temporary directory, show extraction/import progress, load `ubuntu-npu:v2.0.10.2`, and verify `pegasus.py`; never extracts archive contents into the checkout or system paths. |
| `npu-acuity-image-check` | Make target using `docker image inspect` and `docker run` | Host | Verbosely inspect an already-loaded ACUITY image, print metadata and toolkit details, and run `pegasus.py --help` without reloading the archive. |
| `board-npu-golden-test` | `scripts/board-npu-golden-test.sh` | Board | Compare the SDK custom-LUT candidate with its supplied binary golden; does not validate the pinned operator sample. |
| `npu-golden-lenet`, `npu-golden-yolov5`, `npu-golden-resnet50` | `scripts/generate-npu-golden.sh` | Host (Docker + a733_npu_driver checkout) | Verbosely report the selected image, inputs, model, and output, then generate a real ACUITY-quantized NBG/input/host-golden bundle under ignored `work/`; see `docs/optional/npu.md`. |
| `npu-generate-goldens` | `npu-golden-candidate`, `npu-golden-lenet`, `npu-golden-yolov5`, `npu-golden-resnet50` in order | Host | Generate every NPU golden archive; the resnet50 leg fetches the pinned public ONNX via `npu-public-onnx` when absent. Never loads the Docker image itself — generation uses the already-loaded `NPU_ACUITY_IMAGE` and fails fast otherwise. |
| `npu-public-onnx` | `curl` + `sha256sum` | Host | Fetch the pinned public ResNet50 ONNX (`NPU_PUBLIC_ONNX_URL`, verified against `NPU_PUBLIC_ONNX_SHA256`) to `work/images/` when absent; reuse and reverify when present. A custom `NPU_PUBLIC_ONNX` is used as-is, never overwritten or gated. |
| `board-npu-golden-test-lenet`, `-yolov5`, `-resnet50` | `scripts/board-npu-model-test.sh` | Board | Run one of the above goldens and semantically compare (top-K/RMSE/cosine, not memcmp) against its ACUITY host tensor. |
| `board-validation`, `board-status`, `board-report` | matching `scripts/board-*.sh` | Board | Run combined validation or read-only status/evidence collection. |
| `board-headless-benchmark`, `board-system-benchmark` | matching `scripts/board-*.sh` | Board | Run acceleration or CPU/system workloads; storage/network are opt-in. |
| `board-stability-test`, `board-thermal-monitor` | matching `scripts/board-*.sh` | Board | Repeat workloads and record thermal/frequency data. |
| `board-retroarch-*` | RetroArch installer and helpers | Board | Install, validate, repair, test, and remove isolated RetroArch Vulkan. |
| `desktop-*`, `switch-*`, `remote-*` | `scripts/setup-desktop.sh`, `setup-remote.sh` | Board | Select desktop or remote backend; changes services and graphical targets. |
| `backup-*`, `restore` | `scripts/backup.sh`, `restore.sh` | Host | Copy or restore external inputs, caches, and separately confirmed secrets. |
| `collect-boards`, `compare-board-reports` | report collection/comparison scripts | Host + SSH boards | Gather normalized reports and compare boards without changing them. |
| `test`, `tests` | `tests/*.sh` | Host | Run syntax, policy, archive, and pre-boot checks. |

Before using a target, check whether it is host-only, board-only, read-only,
root-writing, destructive, reboot-dependent, or dependent on private vendor
inputs. The target's help text and implementation header are authoritative when
this summary becomes stale.

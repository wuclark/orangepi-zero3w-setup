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
| `board-npu-golden-test` | `scripts/board-npu-golden-test.sh` | Board | Compare the SDK custom-LUT candidate with its supplied binary golden; does not validate the pinned operator sample. |
| `npu-golden-lenet`, `npu-golden-yolov5`, `npu-golden-resnet50` | `scripts/generate-npu-golden.sh` | Host (Docker + a733_npu_driver checkout) | Generate a real ACUITY-quantized NBG/input/host-golden bundle for a named model under ignored `work/`; see `docs/optional/npu.md`. |
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

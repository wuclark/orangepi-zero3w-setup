# Development roadmap

This roadmap records the remaining work for the modular Orange Pi Zero 3W
setup. It does not expand support claims; those require the hardware evidence
specified in `AGENTS.md`.

## Current status

- [x] CLI-only base setup and optional desktop/remote layers.
- [x] Safety-checked PowerVR archive staging and delayed module loading.
- [x] Docker/WSL2 host workflow for generating GPU, VPU, and NPU archives.
- [x] Tracked `work/` layout with Git exclusions for images and proprietary
  outputs.
- [x] Static, shell, and archive tests for the local workflows.
- [x] Host pre-boot extraction test and board post-boot diagnostic scaffold.
- [x] Board-side one-layer-at-a-time runner with persistent progress and
  per-step evidence logs.
- [x] Scoped PowerVR launcher for EGL/GLES and Vulkan application tests.
- [x] Confirm Weston DRM compositor rendering with the PowerVR DDK on HDMI.
- [x] Confirm the current vendor EGL userspace lacks a built Wayland client
  platform; record the native client failure and software fallback.
- [x] Real-image test of the Docker extractor using the pinned source images.
- [x] Implement guarded NPU userspace installation and a pinned execution
  smoke-test path.
- [x] Validate the NPU runtime on the reference Orange Pi: ABI precheck,
  userspace installation, and three successful pinned VIPLite inferences.
- [x] Establish an independent correctness golden for the pinned NPU sample.
  Investigated 2026-09-03: `operator/v3/network_binary.nb` has no golden
  anywhere (checked local `ai-sdk.tar.gz`, `wuclark/ai-sdk`, upstream
  `ZIFENG278/ai-sdk`, `petayyyy/a733_npu_driver`) and no source model, so one
  cannot be independently generated for it either — see the
  `docs/optional/npu.md` roadmap note. Closed 2026-09-08 as superseded: the
  real ACUITY goldens below are board-validated; removal of the
  execution-only sample is tracked separately further down.
- [x] Script real ACUITY-quantized goldens for `lenet`, `yolov5`, and
  `resnet50` (`scripts/generate-npu-golden.sh`, `scripts/board-npu-model-test.sh`,
  `scripts/compare-npu-output.py`) reusing `wuclark/a733_npu_driver`'s
  board-proven ACUITY Docker toolchain, wired into `make` and automatic
  SD-card staging. Generated and board-validated on 2026-09-08; see the
  evidence recorded below.
- [x] Validate VPU H.264 and H.265 runtime decoding on the Orange Pi.
- [ ] Investigate desktop GLX acceleration; resolve the `pvr`/Zink geometry
  shader limitation or document the exact unsupported boundary.
- [ ] Obtain or build a licensed ARM/A733 PowerVR userspace with a working
  Wayland EGL client platform; do not mix the kernel module from another board.
- [ ] Validate native PowerVR Wayland client rendering and determine whether
  the Vulkan ICD can gain safe `VK_KHR_wayland_surface` presentation support.
- [x] Add Docker preloading of the setup repository and generated archives into
  a separate Armbian target image.
- [x] Build and verify a preloaded image from the current Armbian base image;
  the base remains unchanged and the three archive hashes match.
- [ ] Add a dependency-free interactive `sudo make board-config` menu with an
  ANSI dashboard, arrow-key navigation when available, and a numbered-menu
  fallback for serial and limited terminals. It should expose status,
  validation, acceleration, desktop/remote, benchmark, health, backup/restore,
  and reboot actions while showing the equivalent command and requiring
  confirmation for installs, desktop changes, restores, and reboots.
  Deferred to v1.1 (decision log, 2026-09-08): UX convenience, not a
  correctness gate for the proven X11 reference stack.
- [x] Add a lightweight documentation-contract checker to `tests/static-checks.sh`.
  Require a standard explanatory header or a linked guide/exception for each
  maintained script and non-obvious configuration/Make entrypoint, without
  trying to judge prose quality.
- [x] Add project-maintenance references for Make targets, data lifecycle,
  safety boundaries, support claims, design decisions, and evidence format.
- [x] Bring up a Raspberry Pi 5–style PCIe HAT on the Orange Pi Zero 3W:
  Gen2 overlay (`overlays/sun60iw2-pcie-gen2.dts`, PD22 PERST# + PD23 power),
  installer/status scripts, and `docs/optional/pcie.md`. Link-up and
  ASM1182e + VL805/806 enumeration confirmed on kernel
  `6.6.98-vendor-sun60iw2` via `make board-pcie-status`.
- [ ] Verify the PCIe overlay boots cleanly with no HAT attached (cold boot,
  root-bridge-only `lspci`); required before any default-setup discussion.
- [ ] Test NVMe on the PCIe HAT (cold boot, `/dev/nvme0n1` detection) and test
  at least one non-switch PCIe card individually.
- [ ] File sanitized `board-pcie-status` / `board-report` evidence in an issue;
  promote the support-matrix PCIe row only after that evidence lands.
- [ ] Add the PCIe layer as a documented opt-in step in the fresh-install flow
  once the no-HAT boot test passes; keep it out of `board-initial-setup`
  until then.
- [ ] Add a provenance-escrow check for vendor inputs: assert every
  `docs/reference/input-sources.md` acceleration-stack row has a pinned
  SHA-256 in `manifests/reference-stack.env` (or a recorded UNPINNABLE
  reason), anchored on the env file rather than table layout, and audit the
  extractor's hash-refusal path with fixtures before deciding warn-vs-require.
  No live URL checks, no proprietary bytes in CI.
- [ ] Re-validate the reference stack on a schedule: run `board-validation`
  against the newest Armbian image, file the sanitized evidence in an issue,
  and update the pinned inputs when drift breaks a step.
- [ ] Prune on a cadence: remove dead Make targets and superseded guide text
  so the maintained surface stays reviewable.

## Immediate validation TODO

- [x] Run the Docker extractor with the exact pinned Radxa and Orange Pi
  source images.
- [x] Compare generated archives with the real image layouts and tighten all
  GPU/VPU/NPU allowlists.
- [x] Record the verified source-image SHA-256 values and use them in the
  Docker extraction command.
- [x] Run generated archives through `prepare-vendor-archives.sh` on the target
  software stack.
- [x] Test GPU and VPU independently on the Orange Pi; the reference-board
  validation pass includes GPU compute, visible `vkcube` presentation, and
  H.264/H.265 decode evidence.
- [x] Test NPU independently on the Orange Pi with the pinned VIPLite sample;
  retain the sanitized diagnostics and smoke-test evidence in the issue.
- [x] Add and run real GPU workload tests: `vulkaninfo`, GLES/EGL, compute,
  and visibly presented `vkcube`.
- [x] Add real VPU GStreamer H.264/H.265 decode samples and board commands.
- [x] Strengthen VPU validation beyond EOS: generate reproducible local H.264
  and H.265 MP4 samples covering 720p/1080p, 30/60 fps, suitable profiles,
  and controlled keyframes; run them through Cedar; decode them through a
  software reference; and compare normalized frames with PSNR/SSIM. Done
  2026-09-08: all 17 fixtures bit-identical (psnr inf, ssim 1.0) on the
  reference board (kernel `6.6.98-vendor-sun60iw2`); see `docs/optional/vpu.md`.
- [x] Add a pinned VIPLite `vpm_run` NPU execution smoke-test sample.
- [x] Add an independently generated `golden_0.dat` for the exact NPU sample:
  superseded (closed 2026-09-08): investigated 2026-09-03, neither source is
  possible for `network_binary.nb` itself (no golden published anywhere, no
  source model in the SDK to regenerate one from). Tracking happened under the
  `lenet`/`yolov5`/`resnet50` ACUITY-golden line above instead, now
  board-validated; the execution-only sample is retired.
- [x] Run `scripts/generate-npu-golden.sh --model lenet` for real: clone
  `wuclark/a733_npu_driver` to `work/sources/a733_npu_driver`, build its
  ACUITY Docker image per that repo's `docs/01-setup-host.md`, then
  `make npu-golden-lenet`. Done 2026-09-08 on `ubuntu-npu:v2.0.10.2` after
  porting the recipe from the `pegasus_one` wrapper to the explicit
  import/quantize/inference/export flow with fixed mounts and
  `VSIMULATOR_CONFIG` passthrough.
- [x] Fix the yolov5/resnet50 ONNX `--inputs`/`--input-size-list`/`--outputs`
  values in `scripts/generate-npu-golden.sh` against the real ONNX graphs
  (`yolov5s-sim.onnx`, and whichever public ResNet50 ONNX is sourced) — the
  current defaults are unverified best guesses. Done 2026-09-08: yolov5 from
  the SDK's own `inputs_outputs.txt` (`images`, `3,640,640`,
  `350 498 646`); resnet50-v1-12 verified as (`data`, `3,224,224`,
  `resnetv17_dense0_fwd`).
- [x] Source an openly licensed public ResNet50 ONNX file (e.g. ONNX Model
  Zoo/torchvision) for `NPU_PUBLIC_ONNX=` before `make npu-golden-resnet50`
  can run; the SDK ships no resnet50 source weights. Done 2026-09-08:
  `resnet50-v1-12.onnx` (Apache 2.0), pinned URL plus SHA-256 with a
  `npu-public-onnx` fetch target.
- [x] Board-run `make board-npu-golden-test-lenet` / `-yolov5` / `-resnet50`
  on the reference Orange Pi Zero 3W and record real PASS/FAIL evidence
  (top-K match, max/mean abs diff, RMSE, cosine) — required before any
  support claim, per the evidence gate below. Done 2026-09-08:
  `board-validation` 12–13 pass, 0 fail with all three goldens top-5
  matched (kernel `6.6.98-vendor-sun60iw2`, VIPLite
  `2.0.3.2-AW-2024-08-30`).
- [x] Once lenet/yolov5/resnet50 are board-green, remove
  `operator/v3/network_binary.nb` and its `test-npu.sh`/`board-npu-test`
  usage, per the roadmap note in `docs/optional/npu.md`. Done 2026-09-08:
  `stage-npu-test-assets.sh` now sources the executed NBG set from
  `npu-golden-lenet.tar.gz`; `test-npu.sh` and all its callers work
  unchanged on identical filenames.
- [x] Confirm the board-side NPU installer against the target kernel/userspace
  ABI on the reference board; retain the precheck, install, verify, and smoke
  test evidence in the issue.
- [x] Pin the default Docker base image used by extraction and image
  preparation to an immutable official Debian digest.
- [x] Pin the temporary Debian package set by replacing runtime package
  installation with a versioned extraction image.
- [x] Push the latest local commit after review.

## Next implementation steps

1. Investigate desktop GLX acceleration and either resolve the `pvr`/Zink
   geometry-shader limitation or document the exact unsupported boundary.
2. Obtain or build a licensed ARM/A733 PowerVR userspace with a working
   Wayland EGL client platform, then validate native client presentation
   without mixing kernel-module ABIs.
3. Implement the deferred v1.1 `board-config` front end as a thin wrapper
   around the existing Make targets. Keep it display-independent, provide a
   plain-text fallback, and require confirmation for installs, desktop
   changes, restores, and reboots.

## Evidence gate for support claims

Before calling a layer supported, record the board and RAM configuration,
source image checksums, OS/kernel release, module versions and `vermagic`,
userspace/runtime versions, firmware names and hashes, device nodes, relevant
DRM or media state, the exact workload, successful output, and reboot results.
Collect diagnostics with `scripts/collect-diagnostics.sh`; sanitize secrets and
keep the evidence in an issue rather than committing it here.

## Cross-platform boundary

Windows is responsible for image storage, WSL2 invocation, and archive
transfer. Linux/WSL2 Docker performs image mounting and extraction. The Orange
Pi performs board-side staging, installation, and hardware validation. Keep
these boundaries separate so a host-side extraction cannot accidentally alter a
running board or workstation.

# Changelog

## Unreleased

- Consolidate CI on `.github/workflows/static.yml` (static checks, archive
  tests, `git diff --check`, Windows PowerShell syntax) and use
  `actions/checkout@v5` for the Node 24 runtime. Board validation stays
  explicit on real hardware.
- Add an image-drift gate to `sudo ./setup.sh base`: the running kernel and
  OS codename must match the validated reference stack
  (`6.6.98-vendor-sun60iw2` on Debian `trixie`) unless
  `--allow-untested-image` (or `ALLOW_UNTESTED_IMAGE=1`, also wired through
  `make board-base`) is given, so newer Armbian images fail loudly instead of
  breaking later steps.
- Harden `scripts/install-docker.sh`: fail fast with the exact
  `DOCKER_APT_UPDATE=1` rerun when no cached `docker-ce` candidate exists
  (instead of apt's cryptic `no installation candidate`), and remove
  installed conflicting Debian Docker packages (`docker.io`,
  `docker-compose`, and related names) before installing the official
  Engine/Compose packages.
- Add a centralized [fresh-install input sources checklist](docs/reference/input-sources.md)
  linking the base image, vendor source images, SDK, archive workflow, checksums,
  optional tooling, and missing-input recovery paths.

## 1.0.0 - 2026-09-08

- Add `make board-summary` (`scripts/generate-board-summary.sh`): renders a
  sanitized Markdown performance summary from a board-report directory with
  stack, validation, and benchmark tables, aborting on secret-like patterns.
  Add the phased fresh-image bring-up runbook in
  `docs/guide/06-fresh-install-showcase.md` (foundation, acceleration,
  X11/VNC, benchmarks, summary) with extension slots for Wayland and extras.

- Add board-side VPU decode-speed comparison: `scripts/test-vpu-decode-speed.sh`
  times Cedar OMX against software `ffmpeg` per fixture and reports wall/CPU
  seconds, fps, and speedup with governor/CPU evidence. Wired as `make board-vpu-decode-speed`
  and as a section of `make board-headless-benchmark`; figures are
  informational and PASS on completion.

- Add board-side VPU quality comparison: `scripts/test-vpu-quality.sh` decodes
  each fixture through Cedar and software `ffmpeg` to `yuv420p`, requires
  matching frame counts, and records PSNR/SSIM. The 2026-09-08 reference-board
  run was bit-identical across all 17 fixtures; the check remains report-only.
  Wired as `make board-vpu-quality-test` and an optional `board-validation`
  check with SKIP remediation.

- Retire the undocumented `operator/v3/network_binary.nb` fixture:
  `stage-npu-test-assets.sh` now takes the executed NBG set from the
  generated LeNet golden (`--golden`, required) while runner sources,
  headers, and YOLOv5 files still come from the SDK. `test-npu.sh` and all
  callers work unchanged; staging without a golden fails with a pointer to
  `make npu-golden-lenet`, and `extract` skips the bundle with INFO instead
  of breaking `newsd` for non-toolchain setups.

- Make `board-system-benchmark` depend on `board-system-benchmark-deps` and
  let `board-report` record SKIP (keeping an overall PASS) when `sysbench`
  is absent, instead of failing the report on a missing benchmark toolchain.

- Check mounted-image free space against the payload estimate before
  copying the repo in: a shortfall now aborts up front naming
  `PRELOAD_GROW_MB` instead of dying mid-tar with ENOSPC. Estimates err
  upward, so a pass is trustworthy.
- Document legacy-board git bootstrap (init/fetch/reset in place) for cards
  baked before `.git` shipped in the image.

- Assign the embedded repository to UID/GID 1000 during firstboot image
  assembly, so board-side dev works without a manual chown (Armbian creates
  the preset user as UID 1000). Credential-bearing preset files stay
  root-owned; verified inside a test image.

- Promote the ACUITY default to `ubuntu-npu:v2.0.10.2`: all three generated
  goldens passed board top-5 comparison on 2026-09-08 (kernel
  `6.6.98-vendor-sun60iw2`, VIPLite `2.0.3.2-AW-2024-08-30`). The older
  `v2.0.10.1` remains usable via `NPU_ACUITY_IMAGE` override.

- Make `board-gpu-compute-test` depend on `board-gpu-compute-deps` so the
  benchmark toolchain (g++, libvulkan-dev, glslc) is ensured before the run
  instead of failing on a missing shader compiler. The installer is
  idempotent; validation itself stays read-only and skips with remediation
  when the tools are absent.

- Gate the board-validation Vulkan compute benchmark on a shader compiler
  (`glslc` or `glslangValidator`) as well as `g++`/`vulkaninfo`, so a board
  without the compute toolchain reports SKIP with remediation instead of a
  misleading FAIL.

- Ship `.git` (2 MB) inside the preloaded image so the board tree at
  `/opt/orangepi-zero3w-setup` is a real checkout supporting `git pull`;
  commit on the host before baking to avoid inheriting a dirty tree.

- Show installed state in the packages menu (`[installed]` per package group
  backed by `dpkg-query`, GPU-layer readiness for the RetroArch options) so
  re-runs show what is already done without hiding any option.

- Skip RetroArch PowerVR configuration in the packages menu when the board
  GPU layer is absent (missing ICD, `/dev/dri`, or loaded `pvrsrvkm`)
  instead of failing late: Debian packages stay installed, setup continues,
  and the message names the GPU-install then `board-retroarch-install`
  recovery path.

- Write an `[output]` section (`output_N.txt` per host golden tensor) into
  generated NPU golden `sample.txt` files: board `vpm_run` was built without
  `SAVE_OUTPUT_TXT_FILE`, so `--save_txt` silently saved nothing and every
  board comparison failed with "did not produce output_N.txt". The
  `[output]` path saves unconditionally regardless of that compile flag.

- Grow the preloaded SD image by `PRELOAD_GROW_MB` (default 512) before
  copying the repo in: the base root filesystem ships too tight for the
  ~230 MB payload plus vendor archives. The flow extends the single root
  partition (`sfdisk`) and grows the filesystem (`resize2fs`, both newly
  available via the `fdisk` package in the toolchain image), and
  structurally excludes the host-only `backup/` tree from the image.

- Report staged file counts and archive sizes during vendor userspace
  extraction so long silent collection and compression steps show progress.

- Keep `npu-golden-*.tar.gz` across `make clean` (and therefore across
  `make newsd`, which starts from clean): golden archives cost a
  proprietary-toolchain run that `newsd` cannot reproduce, while everything
  else `clean` removes is cheaply rebuilt. Stale goldens are still safe
  because generation refuses to overwrite existing outputs.

- Wire the lenet/yolov5/resnet50 ACUITY goldens into board validation: each
  runs `board-npu-model-test.sh` when its vendor-files archive and the runner
  stack are present, otherwise reports SKIP naming the exact prior step
  (board-npu-install, base setup, or host-side golden generation and
  bake/copy). Existing GPU-compute, VPU, NPU smoke, and golden-candidate
  skips name their remediation the same way.

- Add the `npu-public-onnx` target, which fetches the pinned Apache 2.0 ONNX
  Model Zoo ResNet50 to `work/images/` with SHA-256 verification when absent
  (a custom `NPU_PUBLIC_ONNX` is reused as-is), and wire it into
  `npu-golden-resnet50` so `npu-generate-goldens` runs unattended.

- Verify the ResNet50 NPU golden path end-to-end on `ubuntu-npu:v2.0.10.2`
  with ONNX Model Zoo `resnet50-v1-12` (inputs=data, 3,224,224,
  outputs=resnetv17_dense0_fwd, now the built-in defaults): 40.5 MB int16
  NBG with a 1000-class host output. The converter needs a real image, so
  the generator calibrates on an SDK-bundled COCO sample; the generated golden
  subsequently passed reference-board validation on 2026-09-08.

- Add the `npu-generate-goldens` aggregate target, which generates every NPU
  golden archive in order (candidate, lenet, yolov5, resnet50) after checking
  that `work/images/ai-sdk.tar.gz` and `NPU_PUBLIC_ONNX` are present. It never
  loads the Docker image itself; generation uses the already-loaded
  `NPU_ACUITY_IMAGE` and fails fast otherwise.

- Fix the YOLOv5 NPU golden defaults to the SDK's own
  `models/yolov5s-sim/inputs_outputs.txt` (`images`, `3,640,640`,
  `350 498 646`) instead of the incorrect `640,640,3`/`output` guesses, run
  the driver checkout's non-executable converter via `bash`, and restore host
  ownership of the container-written model and package trees. Host-side
  YOLOv5 generation on `ubuntu-npu:v2.0.10.2` produces a 12.6 MB int16 NBG
  with three host output tensors; the generated golden subsequently passed
  reference-board validation on 2026-09-08. The driver's
  `work/ai-sdk/ZIFENG278-ai-sdk/` checkout may be cloned from the maintained
  `wuclark/ai-sdk` mirror (content-identical; cloned at `aae9287`).

- Fix the LeNet NPU golden recipe, which called the SDK `env.sh` shell function
  `pegasus_one` as if it were a toolkit binary: it now runs the SDK's explicit
  import/quantize/inference/export helpers (which fall back to `python3
  pegasus.py`, so both ACUITY images work) and reproduces the SDK `models/` +
  `../scripts/` layout in the container. Host-side generation on
  `ubuntu-npu:v2.0.10.2` reproduces the board-validated 845,256-byte int16 NBG
  size; the default is pinned to the board-validated `v2.0.10.2` image.
- Document the Imagination open-source driver developer page alongside the
  Vulkan 1.2 blog, with an explicit GPU table showing A733 BXM-4-64 as
  unsupported, and clarify that only a Wayland-enabled build of the same
  closed DDK/BVNC could give native PowerVR Wayland clients.
- Add the host-only `npu-acuity-image-load` target to safely load and verify
  the nested ACUITY Docker image supplied in `work/images`.
- Make the real NPU golden targets automatically clone or reuse the public
  `a733_npu_driver` checkout, while keeping Docker image setup explicit.
- Document the official Allwinner ACUITY archive, Radxa setup guide, and the
  fact that the proprietary image is imported or pulled rather than built from
  a repository Dockerfile.
- Record the Radxa ACUITY usage workflow and its correspondence to this
  project's host-golden and board-side NBG validation flow.

- Add a documentation-contract checker and validated, path-specific legacy exceptions.
- Require sidecars for commentless machine-valid configuration files, including
  schema, consumer, safe-change, and verification documentation.

- Add host and board Make targets for testing the AI SDK custom-LUT NPU golden
  candidate without confusing it with the pinned operator smoke test.
- Include the private NPU golden-candidate check in board validation when its
  archive is present; report it as skipped when the archive is absent.
- Add optional idempotent RetroArch/PowerVR Vulkan installation, validation,
  bounded ALSA testing, configuration repair, and tracked-package uninstall.
- Add repository-core discovery, the `retroarch-powervr` launcher, and RetroArch
  documentation without globally exporting the proprietary PVR library path.
- Add an explicit advanced-core workflow for available Debian packages and
  user-supplied ARM64 Libretro cores.
- Add an opt-in official Libretro aarch64 downloader for PS, N64, PSP, and
  Dreamcast cores with ZIP and ARM64 payload validation.
- Cache downloaded RetroArch core archives with SHA-256 manifests, reusing them
  before falling back to the official latest buildbot path.
- Add read-only display and ALSA status reports for HDMI and USB-C DP testing.
- Add advanced-core checks, automatic ALSA device selection, and a bounded
  headless GPU/VPU/NPU stability test with optional storage testing.
- Add per-iteration ASCII temperature output, CSV data, summary statistics, and
  optional PNG graph generation through the headless gnuplot package.
- Render the accumulated temperature CSV as an ASCII line graph after each
  stability-test iteration.
- Split stability temperature graphs into absolute and delta-from-Skin panels.
- Show the stability-test wait interval and allow it to be configured.
- Make continuous high-load stability testing the default with interval zero.
- Add contributor guidance requiring explanatory documentation and rationale for
  maintained scripts, configuration, and Make targets.
- Expand the documentation checklist with platform assumptions, prerequisites,
  permissions, side effects, provenance, recovery, verification, and examples.

- Exclude generated VPU video fixtures from preloaded images so the small base
  root filesystem does not fill during repository copy.
- Stage the matching sparse PowerVR module source in the SD image so board-side
  module builds do not require a later GitHub fetch.
- Add a VPU target to generate only the two small decode-test video fixtures.
- Let board acceleration targets find embedded vendor archives when invoked from
  a separate checkout.
- Print remediation commands for missing Vulkan compute tools and optional
  x11vnc validation in the board-validation summary.
- Label the expected X11 GLX llvmpipe result as a known limitation that does
  not affect PowerVR Vulkan or EGL.
- Install visible xterm color and font defaults with desktop profiles.
- Add headless system benchmarks for CPU, compression, crypto, memory, optional
  storage, and optional network performance.
- Include the two small VPU decode fixtures in preloaded images when available,
  while excluding the larger fixture collection.
- Add a read-only comprehensive `board-status` report for board setup state.
- Add a PowerVR kernel/module ABI check for safe use after kernel changes.
- Add thermal, frequency, throttling, and available power-sensor logging around
  headless benchmark commands.
- Add a read-only storage-health report for block devices, MMC data, SMART, and
  storage-related kernel errors.
- Avoid issuing eMMC-only EXT_CSD commands against SD cards in storage health
  checks.
- Report the installed NPU runner at its supported path instead of requiring it
  to be on the shell PATH.
- Limit storage kernel-message reporting to the root device instead of mixing
  in unused MMC controllers and Wi-Fi SDIO messages.
- Fix sudo board validation using a nonexistent Xauthority path when checking
  the LightDM-managed X11 display.
- Make board validation safe when invoked through either `make` or `sudo make`
  by avoiding a nested sudo that loses the X11 session context.
- Add normalized board reports, SSH collection for multiple boards, and report
  comparison Make targets.
- Add categorized external-input backup, checksum manifests, and selective
  restore commands with sensitive-file safeguards.
- Explain the recovery command when a required backup input, especially the
  matching kernel source, is missing.
- Explain how to regenerate missing optional vendor output, VPU test data, and
  derived image caches during backup.
- Add the reproducible PowerVR linker/GLVND fix, tty1 Weston service, verifier,
  Make targets, and debugging guide for the A733 Wayland compositor path.
- Have the Weston installer stop competing LightDM and x11vnc services before
  taking ownership of the DRM console.
- Add an explicit XFCE/Xorg counterpart so the established X11 path and the
  Weston path can be switched without competing DRM owners.
- Configure wayvnc from the Weston setup target and start it after the Weston
  Wayland socket becomes available.
- Add release version and Git revision identifiers to generated final image names.
- Make Sway with WayVNC the default Wayland setup; retain Weston as an explicit target.
- Add an opt-in board Docker, Buildx, and Compose installation target.
- Fix desktop session selection incorrectly failing when no reboot is requested.
- Complete the Sway/X11 switching cleanup and remove stale default-session documentation.
- Make the Sway/WayVNC verifier print hidden process-check failures.
- Add a one-command Docker, Compose, Buildx, and container verification target.
- Pin the default Docker image used by the extraction and image-preparation
  stages to an immutable official Debian digest.
- Move temporary extraction-tool installation into a versioned Docker image so
  extraction and image preparation do not refresh apt at runtime.
- Pass Docker repository update and user options through the Make target.
- Show the current login user, detected board address, and local port 15900 in the VNC login banner.
- Use shallow Git clones by default for A733 source synchronization, expose the
  full-history Make override, and document the SD-image SDK boundary.
- Keep source-tree synchronization optional in the all-initial-setup targets;
  acceleration installation uses staged archives and test assets instead.
- Add the acceleration status snapshot and `make board-initial-setup` for the
  foundation plus GPU, VPU, and experimental NPU installers.
- Add `make board-initial-setup-gui` for the complete XFCE/X11 and x11vnc
  setup with LightDM unmasked and enabled.
- Add `make lightdm-mask` and `make lightdm-unmask` for reversible control of
  the LightDM-managed desktop session.
- Make the WayVNC session hook create its state directory, use the resolved
  executable path, and record startup failures instead of exiting silently.
- Ensure the Makefile remote-wayvnc path installs the current session hook.
- Install the `foot` terminal and `wofi` application launcher with the Sway and
  labwc desktop profiles.
- Enforce non-root video-group access to the Cedar VPU device nodes.
- Enforce render-group access to the system DMA heap required by Cedar decode.
- Add `orangepi-tycat` and `orangepi-play-video` wrappers for reliable Wayland
  video preview/playback, and document the DMA-BUF presentation test boundary.
- Name final credential-bearing SD images with a UTC creation timestamp and
  keep `make summary` and `make validate` pointed at the exact artifact.
- Add timestamped progress messages to the Docker userspace extraction stages
  so long-running `make newsd` operations show current activity.
- Reframe the project as `orangepi-zero3w-setup` with a CLI-only base path,
  modular setup dispatcher, optional desktop/remote/GPU layers, and a Windows
  SSH-tunneling guide for VNC viewers.
- Ensure the base and optional desktop/package setup paths do not run `apt
  update` unless explicitly requested.
- Add cross-platform headless Armbian first-boot preset generators and an
  opt-in post-boot software menu.
- Restrict first-boot preset files to Armbian's documented variables and use a
  one-time provisioning hook for hostname configuration.
- Document optional pre-boot copying of unchanged GPU/VPU archives onto the
  prepared SD card, including ownership and permissions.
- Document optional Debian Docker and Docker Compose installation and use.
- Show the x11vnc SSH tunnel command in the login message when remote access is
  configured.
- Make `pvr-userspace.tar.gz` the recommended installer input.
- Add optional `vpu-userspace.tar.gz` discovery and isolated VPU installation.
- Validate archive paths and extract only into private staging directories.
- Add an unchanged Windows archive-transfer script.
- Retain `--vendor-root` as a legacy/debug input.
- Add Codex CLI and Claude Code continuation instructions.
- Add explicit LightDM session entries and reversible X11/Wayland switching,
  including Debian 13 `labwc` support.
- Add Debian 13 `fluxbox` as a lightweight X11 session profile.
- Document the Windows WSL2/`usbipd` workflow for preparing an ext4 SD card.
- Add a repository-owned cross-platform GPU/VPU/NPU userspace extractor for
  mounted root filesystems, producing local archives and checksum manifests;
  no NPU runtime or support claim is added yet.
- Add a Docker/WSL2 image-based extraction wrapper with an ignored but tracked
  `work/` layout for source images and generated archives.
- Add Docker preloading of the repository and generated GPU/VPU/NPU archives
  into a separate Armbian image, with read-only image-content verification.
- Add a second Docker image stage for local first-boot settings, preserving the
  preloaded image as an intermediate artifact.
- Store the preloaded repository at a stable `/opt` path and link it into the
  user selected by the first-boot preset; add pre-write image validation.
- Add a board-side GPU/VPU/NPU step runner with persistent progress and evidence
  logging; it never reboots automatically and refuses unvalidated NPU install.
- Treat expected missing-layer precheck warnings as a recorded baseline while
  keeping post-install verification failures strict.
- Install the GStreamer command-line tools during the explicit VPU install
  phase without refreshing apt metadata.
- Install the VPU `cedarc.conf` configuration and GStreamer parser/runtime
  packages, and add board-side H.264/H.265 OMX decode verification with
  downloaded test media.
- Add Makefile targets for idempotent extraction, staged image creation,
  pre-write validation, and host tests.
- Add a scoped `make clean` for generated outputs that preserves source images.
- Add explicit Make targets for each board GPU/VPU/NPU workflow phase.
- Add a scoped PowerVR application launcher and document EGL/GLES and Wayland
  validation boundaries.
- Add an explicit interactive `make preset` target with credential-safe
  replacement behavior.
- Normalize embedded repository directory traversal permissions for the board
  user while keeping files and vendor archives root-owned.
- Add `make newsd` for a clean, prompted, fully validated SD-card image build.
- Add `ROADMAP.md` documenting the remaining extraction, NPU/VPU validation,
  installer, evidence, and documentation gates.
- Image builds now stage selected A733 NPU test assets from the local AI SDK
  into `npu-test-assets.tar.gz` when available; proprietary source archives
  remain local-only.
- Save persistent NPU smoke-test evidence with kernel, driver, runtime/model
  hashes, and runner output.
- Add a username-independent SSH/maintenance core and optional A733 source
  synchronization under `/opt/orangepi-zero3w-setup/sources`.
- Document the verified Orange Pi CPU numbering and safe workload affinity
  example for leaving a maintenance CPU available.
- Use the maintained `wuclark/linux-orangepi` fork for the default PowerVR
  module source while retaining an explicit repository override.
- Document independent golden-output validation as a future NPU test step;
  the current VIPLite check remains execution-only.
- Add a roadmap and documentation plan for expanded VPU stream coverage and
  hardware-versus-software frame comparison.
- Add local synthetic VPU video generation, prefer those assets during decode
  tests, and install FFmpeg during the explicit VPU install phase.
- Add explicit Make targets and scripts for publishing individual VPU fixtures
  to a pinned GitHub Release and fetching/verifying them on a board.
- Redact credentials from the default SD-image summary and add the explicit
  `make show-unredacted` troubleshooting target.
- Fix the X11 GPU target when a previously installed Weston unit file exists.
- Preserve the disabled Weston unit while switching to the X11 target.
- Start LightDM before x11vnc in the X11 GPU setup target.

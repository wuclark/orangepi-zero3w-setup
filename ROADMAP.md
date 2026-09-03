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
- [ ] Establish an independent correctness golden for the pinned NPU sample.
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
- [x] Add a lightweight documentation-contract checker to `tests/static-checks.sh`.
  Require a standard explanatory header or a linked guide/exception for each
  maintained script and non-obvious configuration/Make entrypoint, without
  trying to judge prose quality.
- [x] Add project-maintenance references for Make targets, data lifecycle,
  safety boundaries, support claims, design decisions, and evidence format.

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
- [ ] Strengthen VPU validation beyond EOS: generate reproducible local H.264
  and H.265 MP4 samples covering 720p/1080p, 30/60 fps, suitable profiles,
  and controlled keyframes; run them through Cedar; decode them through a
  software reference; and compare normalized frames with PSNR/SSIM.
- [x] Add a pinned VIPLite `vpm_run` NPU execution smoke-test sample.
- [ ] Add an independently generated `golden_0.dat` for the exact NPU sample:
  obtain it from the SDK/vendor reference test, or generate it through the
  SDK's CPU/Pegasus path using the matching model, quantization, and
  preprocessing metadata.
- [x] Confirm the board-side NPU installer against the target kernel/userspace
  ABI on the reference board; retain the precheck, install, verify, and smoke
  test evidence in the issue.
- [x] Pin the default Docker base image used by extraction and image
  preparation to an immutable official Debian digest.
- [x] Pin the temporary Debian package set by replacing runtime package
  installation with a versioned extraction image.
- [x] Push the latest local commit after review.

## Next implementation steps

1. Place the exact, checksum-verified Radxa and Orange Pi images in
   `work/images/` and run `scripts/extract-vendor-userspace-docker.sh`.
2. Inspect each generated archive and tighten the GPU/VPU/NPU allowlists to
   the verified package manifests and runtime paths.
3. Record the verified source-image identities and hashes in the generated
   manifests.
4. Continue extending archive validation as real image layouts are confirmed.
5. Confirm the opt-in board-side NPU installer on the target ABI with private
   staging, timestamped backups, recovery support, and no `vipcore.ko` from
   the userspace archive.
6. Run NPU diagnostics and the pinned VIPLite inference smoke test. Require
   `/dev/vipcore`, driver/runtime versions, successful output, and an
   independently generated correctness golden before expanding the claim.
7. Validate GPU, VPU, and NPU on a recoverable Orange Pi with UART access,
   including repeated reboot tests and presentation/media/inference tests.
8. Update README, CLI help, guides, tutorial, changelog, manifests, and
   support claims only after the corresponding evidence exists.
9. Implement the interactive `board-config` front end as a thin wrapper around
   the existing Make targets. Keep it display-independent, use high-contrast
   PASS/WARN/FAIL status colors with a plain-text fallback, and never duplicate
   setup logic or silently install/reboot.

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

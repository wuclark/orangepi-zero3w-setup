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
- [x] Real-image test of the Docker extractor using the pinned source images.
- [ ] NPU userspace installation and runtime validation.
- [ ] VPU runtime validation.
- [x] Add Docker preloading of the setup repository and generated archives into
  a separate Armbian target image.
- [x] Build and verify a preloaded image from the current Armbian base image;
  the base remains unchanged and the three archive hashes match.

## Immediate validation TODO

- [x] Run the Docker extractor with the exact pinned Radxa and Orange Pi
  source images.
- [x] Compare generated archives with the real image layouts and tighten all
  GPU/VPU/NPU allowlists.
- [x] Record the verified source-image SHA-256 values and use them in the
  Docker extraction command.
- [x] Run generated archives through `prepare-vendor-archives.sh` on the target
  software stack.
- [ ] Test GPU, VPU, and NPU independently on the Orange Pi.
- [ ] Add a real GPU workload test: `vulkaninfo`, GLES/EGL, and `vkcube`.
- [ ] Add a real VPU GStreamer decode/encode sample.
- [ ] Add a pinned VIPLite `vpm_run` NPU inference sample.
- [ ] Implement the board-side NPU installer only after its kernel/userspace
  ABI is confirmed.
- [ ] Pin the Docker extraction environment instead of installing unpinned
  packages at every run.
- [ ] Push the latest local commit after review.

## Next implementation steps

1. Place the exact, checksum-verified Radxa and Orange Pi images in
   `work/images/` and run `scripts/extract-vendor-userspace-docker.sh`.
2. Inspect each generated archive and tighten the GPU/VPU/NPU allowlists to
   the verified package manifests and runtime paths.
3. Record the verified source-image identities and hashes in the generated
   manifests.
4. Continue extending archive validation as real image layouts are confirmed.
5. Implement an opt-in board-side NPU installer with private staging,
   architecture/ABI checks, timestamped backups, and uninstall/recovery
   support. Do not install `vipcore.ko` from the userspace archive.
6. Add NPU diagnostics and a pinned VIPLite inference smoke test. Require
   `/dev/vipcore`, driver/runtime versions, and successful output.
7. Validate GPU, VPU, and NPU on a recoverable Orange Pi with UART access,
   including repeated reboot tests and presentation/media/inference tests.
8. Update README, CLI help, guides, tutorial, changelog, manifests, and
   support claims only after the corresponding evidence exists.

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

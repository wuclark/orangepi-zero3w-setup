# Changelog

## Unreleased

- Make the WayVNC session hook create its state directory, use the resolved
  executable path, and record startup failures instead of exiting silently.
- Ensure the Makefile remote-wayvnc path installs the current session hook.
- Install the `foot` terminal and `wofi` application launcher with the Sway and
  labwc desktop profiles.
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

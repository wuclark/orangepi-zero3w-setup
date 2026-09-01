# Changelog

## Unreleased

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
- Add Makefile targets for idempotent extraction, staged image creation,
  pre-write validation, and host tests.
- Add a scoped `make clean` for generated outputs that preserves source images.
- Add explicit Make targets for each board GPU/VPU/NPU workflow phase.
- Add an explicit interactive `make preset` target with credential-safe
  replacement behavior.
- Normalize embedded repository directory traversal permissions for the board
  user while keeping files and vendor archives root-owned.
- Add `make newsd` for a clean, prompted, fully validated SD-card image build.
- Add `ROADMAP.md` documenting the remaining extraction, NPU/VPU validation,
  installer, evidence, and documentation gates.

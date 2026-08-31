# Changelog

## Unreleased

- Reframe the project as `orangepi-zero3w-setup` with a CLI-only base path,
  modular setup dispatcher, optional desktop/remote/GPU layers, and a Windows
  SSH-tunneling guide for VNC viewers.
- Ensure the base and optional desktop/package setup paths do not run `apt
  update` unless explicitly requested.
- Add cross-platform headless Armbian first-boot preset generators and an
  opt-in post-boot software menu.
- Make `pvr-userspace.tar.gz` the recommended installer input.
- Add optional `vpu-userspace.tar.gz` discovery and isolated VPU installation.
- Validate archive paths and extract only into private staging directories.
- Add an unchanged Windows archive-transfer script.
- Retain `--vendor-root` as a legacy/debug input.
- Add Codex CLI and Claude Code continuation instructions.
- Add explicit LightDM session entries and reversible X11/Wayland switching,
  including Debian 13 `labwc` support.
- Add Debian 13 `fluxbox` as a lightweight X11 session profile.

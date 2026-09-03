# Evidence format

Board evidence must be reproducible, timestamped, and sanitized before sharing.
Use `make board-report` for normalized results and
`scripts/collect-diagnostics.sh` for broad troubleshooting data.

## Required identity

- Board model, revision, RAM, and device-tree compatible string.
- OS/image identity and source-image SHA-256.
- `uname -a`, architecture, and kernel release.
- Module path, name, `vermagic`, source commit, DDK build, BVNC, and firmware names/hashes.

## Required runtime evidence

- DRM device nodes, debugfs names, connector status, and optional media/NPU nodes.
- `vulkaninfo --summary` with the selected ICD.
- EGL/GLES renderer and X11 DRI2/DRI3/Present output.
- Exact workload command, result, timing, temperature range, and reboot count.
- VPU codec/profile/resolution/frame-rate and NPU model/test metadata.
- RetroArch core filename, architecture/dependency check, Vulkan context, and audio device.

## Privacy and comparison

Remove passwords, Wi-Fi data, unnecessary IPs, VNC hashes, SSH host keys,
tokens, ROM paths, and private filenames. Do not commit complete board logs or
generated vendor data. Multi-board reports should use stable `key=value` names,
keep PASS/WARN/FAIL/SKIP separate from diagnostic text, and show missing fields
instead of treating them as passing values.

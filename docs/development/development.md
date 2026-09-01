# Continuing development with Codex CLI or Claude Code

The general project entry point is `setup.sh`; the PowerVR `install.sh` flow is
an optional, safety-sensitive module. The base setup is intentionally CLI-only
and never runs `apt update` unless the user explicitly requests it.

Track unfinished implementation work in [ROADMAP.md](../../ROADMAP.md). Keep
the roadmap status aligned with tested code and do not mark a hardware layer
complete from static or archive tests alone.

## Start a session

```bash
git clone https://github.com/YOUR-USERNAME/orangepi-zero3w-setup.git
cd orangepi-zero3w-setup
codex
# or: claude
```

Suggested first prompt:

```text
Read AGENTS.md, docs/development/development.md, docs/reference/architecture.md, and the reference
manifest. Inspect git status. Work only on issue #NUMBER. Preserve the supported
stack and proprietary-file exclusions. Run all required tests and report which
checks are local-only versus run on real hardware.
```

## Branch and test

```bash
git switch -c fix/short-description
./tests/static-checks.sh
./tests/test-archives.sh
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
git diff --check
```

Do not ask an agent to execute `install.sh` on a laptop or generic VM. Installation
tests belong on a recoverable Orange Pi with UART available. Use a separate SD
card, save diagnostics before and after, and keep the prior bootable card.

## Issue evidence for a new supported stack

Include: board revision/RAM, OS image and checksum, `uname -a`, module source
commit, `modinfo pvrsrvkm`, firmware names/hashes, `/dev/dri`, debugfs DRM names,
`vulkaninfo --summary`, EGL renderer, X11 DRI2/DRI3/Present, reboot count, and
whether `vkcube` was visibly presented. A boot alone is insufficient.

## Hardware references

The Orange Pi Zero 3W A733 user manual v1.0 and board schematic v1.2 were used
to confirm the A733 platform, HDMI 2.0 display path, PCIe/USB high-speed interface,
5 V/3 A power target, and 12 GB configuration. They are reference documents,
not permission to generalize software compatibility.

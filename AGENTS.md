# Agent instructions

This repository provides modular setup guidance for the Orange Pi Zero 3W /
Allwinner A733. The base system is CLI-only; the proprietary PowerVR DDK and
out-of-tree kernel module are optional, narrowly tested layers. Treat GPU boot
sequencing and ABI checks as safety-critical.

## Before changing anything

1. Read `README.md`, `docs/development/development.md`,
   `docs/reference/architecture.md`, and
   `manifests/reference-stack.env`.
2. Preserve the clean-room rule: never commit generated vendor archives,
   extracted proprietary files, firmware, or `pvrsrvkm.ko`.
3. Do not broaden the support matrix without real-board evidence containing
   kernel release, module `vermagic`, DDK build, BVNC, DRM nodes, DRI3 output,
   `vulkaninfo --summary`, and a successful presentation test.
4. Never extract an untrusted archive over `/`. Use
   `scripts/prepare-vendor-archives.sh` and stage privately first.
5. Never remove or shorten the delayed module-load ordering without a documented
   reboot test and serial-console recovery plan.

## Development workflow

- Make small, reviewable changes; preserve unrelated user work.
- Use `apply_patch` for edits.
- Run `tests/static-checks.sh`, `bash -n` on every shell script, PowerShell
  parsing when `pwsh` exists, `git diff --check`, and `tests/test-archives.sh`.
- Do not run installers on a development workstation. Hardware tests must be
  explicit and occur on the target board.
- The base and desktop/package setup paths must not run `apt update` unless the
  user explicitly passes an update option.
- Update README, CLI help, step-by-step guide, tutorial, and changelog whenever
  an input, option, installed path, or support claim changes.
- Record hardware test evidence using `scripts/collect-diagnostics.sh` and put
  sanitized results in an issue; never commit secrets, host keys, or VNC hashes.

## Definition of done

The modular base flow, archive flow, legacy extracted-tree flow, dry/static tests, documentation,
uninstall/recovery instructions, and Git exclusion rules agree. A maintainer can
explain every root write and every boot-order dependency from the diff alone.

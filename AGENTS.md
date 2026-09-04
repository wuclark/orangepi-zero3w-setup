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
- Keep every executable shell script under `scripts/` and `tests/` executable
  in Git (`chmod 755 script.sh`); a script invoked as `./script.sh` must never
  be committed with mode `644`.
- Run `tests/static-checks.sh`, `bash -n` on every shell script, PowerShell
  parsing when `pwsh` exists, `git diff --check`, and `tests/test-archives.sh`.
  `bash -n` is the shell syntax check; ShellCheck is not required by this
  repository process.
- Keep the project map in `docs/development/project-map.md` aligned with new
  directories, entrypoints, and host/board boundaries. When the documentation
  contract checker is added, run it as part of the same local verification and
  fix or explicitly exempt every changed script/configuration file.
- Keep these companion references current and linked from the project map:
  `make-target-index.md`, `data-lifecycle.md`, `safety-boundaries.md`,
  `support-matrix.md`, `decision-log.md`, and `evidence-format.md`. Update the
  relevant reference when a target, artifact flow, safety boundary, support
  claim, design decision, or evidence field changes.
- Do not run installers on a development workstation. Hardware tests must be
  explicit and occur on the target board.
- The base and desktop/package setup paths must not run `apt update` unless the
  user explicitly passes an update option.
- Update README, CLI help, step-by-step guide, tutorial, and changelog whenever
  an input, option, installed path, or support claim changes.
- Treat documentation as part of every implementation: each maintained
  executable script and each non-obvious configuration file must explain its
  purpose, inputs, outputs, root/system writes, safety boundaries, important
  design decisions, known limitations, and safe extension points. Put concise
  rationale comments beside non-obvious code and link to a detailed guide when
  the explanation is too large for the file. Documentation should teach a new
  maintainer how the component works and why it works that way, not merely list
  the command that invokes it.
- For machine-valid, human-maintained commentless configuration files, use a
  same-name `.md` sidecar when comments are impossible. The sidecar must name
  the file's purpose and consumer, exact schema constraints, safe changes,
  verification commands, and why comments cannot be used. A linked guide may
  serve instead only when the documentation-contract checker explicitly records
  that exception.
- Include, where applicable, the supported board/OS/architecture/kernel,
  prerequisites and required packages/services/devices, permission and sudo
  requirements, idempotency and repeat-run behavior, created or modified
  paths/services, download provenance, cleanup/rollback/recovery behavior,
  expected exit and failure behavior, log/evidence locations, security/privacy
  considerations, verification commands, normal and advanced examples, and
  explicit non-goals. Do not document a capability as supported unless the
  corresponding verification evidence exists.
- Record hardware test evidence using `scripts/collect-diagnostics.sh` and put
  sanitized results in an issue; never commit secrets, host keys, or VNC hashes.

## Definition of done

The modular base flow, archive flow, legacy extracted-tree flow, dry/static tests, documentation,
uninstall/recovery instructions, and Git exclusion rules agree. A maintainer can
explain every root write and every boot-order dependency from the diff alone.

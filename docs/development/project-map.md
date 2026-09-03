# Project map

This map describes the repository boundaries so contributors can find the
right layer before changing code. The host builds images and archives; the
Orange Pi installs and validates them. Proprietary inputs and generated output
remain outside Git.

```text
.
├── setup.sh, install.sh, Makefile       public host/board entrypoints
├── README.md, ROADMAP.md, CHANGELOG.md  project usage and status
├── AGENTS.md, CONTRIBUTING.md           maintenance and review policy
├── config/                              files staged into board images
├── manifests/                           reference versions and support inputs
├── scripts/
│   ├── extract-*, prepare-*, build-*    host image/archive production
│   ├── armbian-*, create-*              image first-boot provisioning
│   ├── setup-*, install-*, uninstall-*  board system changes
│   ├── board-*, test-*, verify-*        board diagnostics and validation
│   ├── collect-*, compare-*              evidence and multi-board reports
│   └── lib.sh                            shared shell helpers and constants
├── tests/
│   ├── host/                             pre-boot host workflow tests
│   ├── board/                            explicit real-board test entrypoints
│   ├── static-checks.sh                  syntax/policy/path checks
│   └── test-archives.sh                  generated archive safety checks
├── docs/
│   ├── development/                      contributor workflow and this map
│   ├── guide/                            step-by-step setup and recovery
│   ├── optional/                         GPU, VPU, NPU, and RetroArch layers
│   ├── reference/                        architecture, hardware, status, support
│   ├── remote/                           SSH/VNC/remote-display procedures
│   └── legacy/                           historical paths retained for reference
├── docker/                               pinned extraction/build context
├── windows/                              WSL2 and Windows transfer helpers
├── systemd/                              service units staged for board services
├── benchmarks/                           benchmark source/configuration
├── npu-test/                             source/test metadata; generated assets excluded
├── testdata/                             reproducible test inputs; generated media excluded
├── vendor-files/                         private archive handoff location
├── build-pvrsrvkm/                       private kernel/module source workspace
└── work/                                 ignored images, archives, and derived output
```

## Common paths and boundaries

Host-side commands run on Linux or WSL2 and may use Docker, loop devices, and
temporary mounts. They write only to the checkout's ignored `work/` and private
build/cache paths unless an explicit output is supplied.

Board-side commands normally run with `sudo` after the image boots. Installers
write system paths under `/opt`, `/usr`, `/etc`, `/var/lib`, or `/var/log` only
when their documentation says so. Validation, status, diagnostics, and report
commands are intended to be read-only.

The PowerVR kernel module and proprietary userspace are safety-sensitive. GPU
installation is delayed until after boot, and the board must pass ABI checks
before GPU workloads are used. Never add generated vendor archives, firmware,
credentials, or derived images to Git.

When adding a workflow, identify its boundary explicitly: host build,
first-boot image, board installation, board validation, or evidence/reporting.
Add the public Make target and guide link in the same change.

Related development references:

- [Make-target index](make-target-index.md)
- [Data lifecycle](data-lifecycle.md)
- [Safety boundaries](safety-boundaries.md)
- [Support matrix](support-matrix.md)
- [Decision log](decision-log.md)
- [Evidence format](evidence-format.md)

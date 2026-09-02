# Testing workflows

The tests are split by where they are safe to run.

## Host/pre-boot tests

Run these on Linux or WSL2 before copying archives to the board:

```bash
./tests/host/test-preboot-extraction.sh
```

This uses synthetic files only. It checks archive isolation, required runtime
shapes, checksum manifests, and rejection of kernel modules. It does not prove
that a particular vendor image contains a compatible runtime. Test the real
images with:

```bash
./scripts/extract-vendor-userspace-docker.sh
```

After extraction, the preboot image stages can be exercised with
`scripts/prepare-preloaded-image-docker.sh` and
`scripts/prepare-firstboot-image-docker.sh`. Both produce separate derived
images and leave their inputs unchanged; the latter requires local,
Git-ignored first-boot files.

The host suite also has a Make target alias:

```bash
make tests
```

## Board/post-boot tests

After the archives and matching module have been installed on a recoverable
Orange Pi with UART access, run:

```bash
./tests/board/test-postboot-acceleration.sh
```

Select only the layers being tested when the others are not installed:

```bash
./tests/board/test-postboot-acceleration.sh --gpu --output work/gpu-test.txt
./tests/board/test-postboot-acceleration.sh --npu --output work/npu-test.txt
```

The board test is diagnostic only: it does not install packages, load modules,
change boot ordering, or reboot. It checks kernel/module identity, device
nodes, firmware, runtime libraries, and available GPU/VPU/NPU smoke-test tools.
Run `scripts/collect-diagnostics.sh` before and after hardware testing and put
sanitized results in an issue, not in this repository.

For a recorded one-layer-at-a-time workflow, run the board orchestrator on the
Orange Pi:

```bash
sudo ./scripts/board-acceleration-workflow.sh --layer gpu --action precheck
sudo ./scripts/board-acceleration-workflow.sh --layer gpu --action install
sudo reboot
sudo ./scripts/board-acceleration-workflow.sh --layer gpu --action verify
```

Repeat the same sequence for `vpu`. VPU verification downloads test media and
runs explicit H.264/H.265 OMX decode pipelines; use
`make board-vpu-decode-test` to rerun those tests directly. Use `npu` for
precheck only until the board-side NPU installer is implemented. Progress is appended to
`/var/log/orangepi-zero3w-setup/acceleration-progress.log`, with per-step
evidence files beside it. The orchestrator never reboots automatically.
Prechecks record missing layers as a baseline and exit successfully; verify
steps return failure when required checks are still missing.

Equivalent Make targets are available on the board:

```bash
sudo make board-gpu-precheck
sudo make board-gpu-install
sudo reboot
sudo make board-gpu-verify
```

Use the corresponding `board-vpu-*` targets for VPU. `board-npu-install`
intentionally exits without installing anything.

For a single diagnostic pass without installation or reboot, select the layer:

```bash
sudo make board-test BOARD_LAYER=gpu
sudo make board-test BOARD_LAYER=vpu
sudo make board-test BOARD_LAYER=npu
```

`BOARD_LAYER=all` is also available when all three layers are intentionally
installed. The per-layer test targets combine the existing verification steps:
`make board-gpu-test` runs GPU post-install and runtime checks, `make
board-vpu-test` also runs the H.264/H.265 decode tests, and `make
board-npu-test` runs the NPU smoke test. Use `make board-diagnostics` to
capture the broader pre/post hardware evidence. These targets never install,
reboot, or change boot ordering; visible `vkcube` presentation remains a
manual test.

For one consolidated post-install report, run:

```bash
sudo make board-validation
```

It runs the available layer checks and workloads, reports `PASS`, `FAIL`, or
`SKIP`, and saves a timestamped report under
`/var/log/orangepi-zero3w-setup/`. A missing optional layer is reported as a
failure by its device check, while workload prerequisites that are absent are
reported as skipped. The command never installs, reboots, or changes boot
ordering.

Keep real images, extracted roots, archives, logs, models, and test output under
the ignored `work/` directory or outside the repository.

The final `make newsd` summary is a handoff record only: it reports paths,
hashes, selected non-secret settings, and whether credentials are set. It does
not print passwords.

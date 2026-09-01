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

Repeat the same sequence for `vpu`. Use `npu` for precheck only until the
board-side NPU installer is implemented. Progress is appended to
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

Keep real images, extracted roots, archives, logs, models, and test output under
the ignored `work/` directory or outside the repository.

The final `make newsd` summary is a handoff record only: it reports paths,
hashes, selected non-secret settings, and whether credentials are set. It does
not print passwords.

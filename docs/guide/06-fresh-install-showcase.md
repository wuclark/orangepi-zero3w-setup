# Fresh-image full bring-up (X11 showcase)

Starting point: a preloaded image built with `make newsd` (repository plus
GPU/VPU/NPU archives baked in). End state: everything installed that this
guide covers, validated, benchmarked, and summarized in one sanitized Markdown
file for a GitHub issue. Keep serial/UART access attached until the end.

Extension slots for later phases are marked `PLAN:` — Wayland, RetroArch, and
Docker slot in without changing the phases below.

## Phase A — foundation and acceleration install

After first boot and SSH (see `00-prepare-sd-card.md` and
`01-first-boot-wifi.md`):

```bash
cd ~/orangepi-zero3w-setup
sudo make board-foundation
sudo make board-acceleration-install
```

This installs the base, packages, core, sources, then the GPU, VPU, and NPU
layers. It does not reboot.

```bash
sudo reboot
```

## Phase B — verify and validate (after reboot)

The delayed `pvrsrvkm` service needs ~30 seconds plus Xorg startup; wait about
two minutes after SSH returns:

```bash
cd ~/orangepi-zero3w-setup
sudo make board-validation
```

Expect `Totals: pass=14 fail=0 skip=0` (counts grow as layers are added; zero
fail is the bar). On failure, see `docs/reference/troubleshooting.md` before
continuing — do not install the desktop on a red validation.

## Phase C — X11 desktop and remote access

```bash
cd ~/orangepi-zero3w-setup
sudo make board-initial-setup-gui
sudo reboot
```

After SSH returns, confirm the display and VNC service, then re-validate so
the X11 checks run against the real session:

```bash
sudo make board-display-status
sudo make board-validation
```

`PLAN:` Wayland second path — `board-gpu-sway-setup`, verify, re-validate,
then switch back with `board-gpu-x11-setup`. `PLAN:` extras — RetroArch
(`board-retroarch-install`), Docker (`board-docker-install`).

## Phase D — benchmarks, report, summary

```bash
cd ~/orangepi-zero3w-setup
sudo make board-headless-benchmark
sudo make board-report
sudo make board-summary
```

`board-summary` renders `SUMMARY.md` inside the latest report directory from
`board-report` output plus the validation evidence logs. Generation aborts on
secret-like patterns and redacts LAN IPv4 addresses. Review the file, copy it
plus the cited evidence logs off the board (never commit them), and attach
everything to a GitHub issue. Worked example: issue #2 (2026-09-08 full
bring-up, 14/14 green). Durable headline numbers may graduate into the
guide docs afterwards, as the VPU quality reference did in `docs/optional/vpu.md`.

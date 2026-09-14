# touch-rightclick.service

## Purpose

Run the long-press-to-right-click daemon for single-touch Waveshare panels at
boot. The daemon watches the touch event device read-only and injects
right-clicks through its own transient uinput device.

## Consumer

`systemd` on the board. Installed and enabled by
`scripts/install-touch-rightclick.sh`; removed by its `--uninstall` action.

## Exact schema constraints

Standard systemd unit schema: `Unit`, `Service`, `Install` sections.
`ExecStart` must point at the installed daemon path
`/usr/local/sbin/orangepi-touch-rightclick` with explicit tuning flags
(`--device-name`, `--gesture`, `--hold-ms`, `--move-units`). `Restart=always` is required
so USB re-enumeration or transient input errors recover without manual action.
`StartLimitIntervalSec`/`StartLimitBurst` cap systemd-level restarts so a
structural failure (e.g. missing `/dev/uinput`) fails visibly instead of
restart-spinning forever; in-daemon USB re-scanning is unaffected. The unit
itself stays comment-free by repository convention; this rationale lives here
rather than inline.
Do not add reboot, shutdown, or early-boot ordering directives: this service
is input-only and must not participate in the delayed GPU module sequencing.

## Safe changes

Tune `--gesture` (`hold`: press-and-hold fires; `tap-hold`: a quick tap
followed by a held press fires, leaving a plain long-press free for
drag/select), `--hold-ms` (press-and-hold deadline) and `--move-units` (jitter
allowance in ABS device units) for the panel and user. Change
`--device-name` when the panel reports a different input name (find it with
`sudo evtest`). Prefer `systemctl edit touch-rightclick.service` drop-ins for
local tuning over editing the shipped unit.

## Verification

`systemctl status touch-rightclick.service`, `journalctl -u
touch-rightclick.service` (shows device-watch and right-click lines), then
hold a finger still on the panel and confirm the context menu appears while
short taps and drags behave as before.

## Why comments are impossible

This is a systemd unit file: `#` lines are technically allowed, but this
repository treats `systemd/` payloads as commentless machine-valid
configuration validated by the documentation-contract checker, so rationale
lives in this sidecar and in `docs/optional/touch-rightclick.md`.

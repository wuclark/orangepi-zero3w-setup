# Touchscreen long-press right-click

Single-touch Waveshare panels (e.g. the WS170120, an eGalax `0eef:0005`
controller) report `ABS_X`/`ABS_Y`/`BTN_TOUCH` with no multi-touch slots, so
two-finger gestures are impossible at every layer: the kernel never sees a
second finger. This page covers the long-press daemon that gives those panels
a right-click on both X11 and Wayland sessions.

X11-only helpers such as `mousetweaks` cannot run under `sway`/`labwc`, which
is why this daemon lives at the kernel-input layer instead: it watches the
touch event device read-only and injects `BTN_RIGHT` through its own transient
uinput device. The watched device is never grabbed, so killing or removing the
daemon restores plain touch immediately.

## Install

```bash
sudo ./setup.sh touch-rightclick
```

or equivalently `sudo make board-touch-rightclick-install`. This installs
`python3-evdev` (plus `python3-xlib` for the xtest backend and the `xinput` /
`evtest` touch diagnostics) from the existing apt cache (pass `--update` to
refresh it first), runs the built-in detector self-test, and enables/starts
`touch-rightclick.service`. It never reboots and touches nothing in the GPU,
desktop, or remote stacks.

True multi-touch (two-finger tap, pinch) is a hardware-plus-kernel matter:
the WS170120 panel is 5-point capacitive, but the stock
`6.6.98-vendor-sun60iw2` kernel omits `hid-multitouch` (and uinput), so
generic HID exposes single-touch only. That gap is now closable without
rebuilding the kernel (see below); until then the long-press daemon is the
supported answer.

## True multitouch (out-of-tree module)

Upstream `hid-multitouch` v6.6.98 builds against the matching vendor headers
and loads on the tested kernel, after which the panel reports per-contact
slots and tracking IDs (five simultaneous contacts observed 2026-09-14):

```bash
sudo make board-touch-multitouch-install
```

This targets exactly `6.6.98-vendor-sun60iw2` on aarch64 and aborts
otherwise; it uses the existing apt cache unless `--update` is passed, pins
the upstream sources by SHA-256 (verified independently), checks the compiled
module's `vermagic` before installing to
`/lib/modules/<kernel>/updates/`, and never replaces the kernel or reboots.
Afterwards reconnect only the touchscreen USB data connection and verify:

```bash
sudo evtest
```

Expect `ABS_MT_SLOT`, `ABS_MT_POSITION_X/Y`, `ABS_MT_TRACKING_ID`, and
multiple active contacts at once; only `ABS_X`/`ABS_Y`/`BTN_TOUCH` means the
stock driver is still bound. Reboot-time autoload was not demonstrated in the
first test: after a reboot, check `lsmod | grep hid_multitouch` and `evtest`,
run `sudo modprobe hid_multitouch` if needed, and only then consider pinning
`hid_multitouch` via `/etc/modules-load.d/`. The module is per-kernel: after
a kernel update, check whether the new kernel includes the driver, otherwise
rebuild for it — never copy the `.ko` across kernels. Remove with
`sudo make board-touch-multitouch-uninstall` (then reconnect USB to return to
the stock driver). Kernel-level contacts do not imply desktop gestures: if
`evtest` shows fingers but an app ignores them, the mapping lives in the
desktop/application layer, not here.

## Backends

- `uinput` injects at the kernel layer and reaches X11 and Wayland sessions,
  but needs `/dev/uinput`. The installer loads and persists the module when
  present. Force it with `--backend uinput`.
- `xtest` injects through the X11 XTEST extension: no kernel support needed,
  but X11 sessions only. The installer selects it automatically when uinput
  is unavailable (observed on the `6.6.98-vendor-sun60iw2` kernel, which
  ships no uinput at all) and installs `python3-xlib` for it. It authenticates
  by scanning authority candidates (explicit `--xauthority`, the LightDM root
  authority, the recorded login user's `~/.Xauthority`) and live X sockets
  (`--display` first), re-resolving on every failed connect so boot races and
  `:0`/`:1` shuffles recover on the next hold.
- `auto` (default) picks uinput when available, else xtest.

Tuning (defaults suit the WS170120):

- `--hold-ms` (default 500): how long the finger must stay still. Lower it
  (e.g. 350) for a snappier click, raise it (e.g. 800) if menus fire while
  you are starting a drag. Re-run the installer with the new value to apply
  it — reinstalling is idempotent and restarts the service:

```bash
sudo ./setup.sh touch-rightclick --hold-ms 400
```

```bash
sudo ./setup.sh touch-rightclick --gesture tap-hold --hold-ms 800
```

- `--gesture hold` (default): press one finger, keep it still past `--hold-ms`,
  lift. Simple and discoverable. The click fires on lift so the menu opens
  with no buttons down; wandering past the allowance before lifting cancels,
  so drags never misfire.
- `--gesture tap-hold`: quick tap followed by a held press (also firing on
  lift), for hands where even a plain hold should never summon a menu.
  `--tap-window-ms` (default 400) bounds the gap between the tap and the
  held press.
- **Two-finger tap**: tap with two fingers and lift both within `--tap-ms`
  (default 300). Needs `ABS_MT_SLOT` support — i.e. the multitouch module
  above — and the daemon enables it automatically when the slots are present
  (`--tap-ms 0` disables it). The click lands at the pair midpoint (the XTEST
  backend warps the cursor there first; the button-only uinput device clicks
  at the current position). A second live contact disarms the single-finger
  hold for that chord, so the two gestures never double-fire; holds, drags,
  and three-finger touches never trigger it.
- `--hold-ms` (default 500): how long the finger must stay still. Lower it
  (e.g. 350) for a snappier click, raise it (e.g. 800) if menus fire while
  you are starting a drag.
- `--move-units` (default 12 ABS units): motion past this cancels the pending
  click, so drags and scrolls never right-click.
- `--move-fraction` (e.g. 0.02): portable alternative to `--move-units` —
  a fraction of the larger axis range, read from the device at startup
  (0.02 of a 720-range panel ≈ 14 units, close to the default). Overrides
  `--move-units` when set; the journal logs the computed units. Prefer it on
  panels whose coordinate range differs from this one. It is a portability
  heuristic, not finger physics: equal fractions cover different millimeters
  on different-sized panels.
- `--device-name` (default `WS170120`): substring matched against the input
  device name; find yours with `sudo evtest`.

Re-run the installer with new values to apply them — reinstalling is
idempotent and restarts the service.

The click injector needs `/dev/uinput` in the uinput backend: the installer
loads the `uinput` module and persists it via
`/etc/modules-load.d/touch-rightclick.conf` (plain `uinput` line only —
unrelated to the delayed `pvrsrvkm` sequencing). The xtest backend needs
neither. A structural failure in either backend fails visibly instead of
restart-spinning, by design;
check `journalctl -u touch-rightclick.service` in that case.

## Verify

1. `systemctl status touch-rightclick.service` is active; `journalctl -u
   touch-rightclick.service` shows the watched device and each emitted click.
2. Hold a finger still past the deadline, then lift: the context menu appears
   and stays open, and the next tap selects normally. (The click fires on
   lift deliberately: firing mid-hold leaves a dangling press whose release
   dismisses the menu or triggers the item under the finger.) Short taps and
   drags behave exactly as before.
3. Hardware-free check of the detector logic:
   `python3 scripts/orangepi-touch-rightclick --self-test`.
4. If gestures misfire or never fire, reinstall with `--debug` and watch the
   per-press verdicts (drift amounts, chord durations, cancel reasons):
   `sudo ./setup.sh touch-rightclick --debug`, then
   `sudo journalctl -u touch-rightclick.service -f` while touching.

## Remove

```bash
sudo ./setup.sh touch-rightclick --uninstall
```

or `sudo make board-touch-rightclick-uninstall`. Plain touch keeps working;
installed desktop packages are preserved (as with the desktop reset path).

## Known limitations

- The press itself still reaches the stack as a left-press (the daemon
  observes without grabbing, by design), but the click fires on lift so the
  press completes first and the menu opens with no buttons down. Moving past
  the allowance before lifting cancels, so drags never misfire; prefer
  `tap-hold` when even a plain hold should never summon a menu.
- Two-finger tap, pinch, and other multi-touch gestures need the out-of-tree
  `hid-multitouch` module above; on the stock driver the panel is
  single-touch only. A USB mouse works alongside touch with no configuration.
- Needs `/dev/uinput` and event-device read access; the service runs as root
  for this reason. It is input-only and stays out of the delayed `pvrsrvkm`
  boot sequencing.

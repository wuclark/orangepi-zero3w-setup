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
the WS170120 panel is 5-point capacitive, but the
`6.6.98-vendor-sun60iw2` kernel ships neither `hid-multitouch` nor uinput,
so generic HID exposes single-touch only. Enabling it would require
rebuilding the vendor kernel — disproportionate next to the working
long-press path, so this daemon is the supported answer.

## Backends

- `uinput` injects at the kernel layer and reaches X11 and Wayland sessions,
  but needs `/dev/uinput`. The installer loads and persists the module when
  present. Force it with `--backend uinput`.
- `xtest` injects through the X11 XTEST extension: no kernel support needed,
  but X11 sessions only. The installer selects it automatically when uinput
  is unavailable (observed on the `6.6.98-vendor-sun60iw2` kernel, which
  ships no uinput at all) and installs `python3-xlib` for it. It addresses
  display `:0` with the LightDM root authority by default
  (`--display`/`--xauthority` override).
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

- `--gesture hold` (default): press-and-hold-still fires. Simple and
  discoverable, but it claims the plain long-press: holding still and then
  dragging will have fired a right-click first.
- `--gesture tap-hold`: a quick tap followed by a held press fires, leaving a
  plain long-press free for drag/select gestures. `--tap-window-ms`
  (default 400) bounds the gap between the tap and the held press.
- `--hold-ms` (default 700): how long the finger must stay still.
- `--move-units` (default 12 ABS units): motion past this cancels the pending
  click, so drags and scrolls never right-click.
- `--device-name` (default `WS170120`): substring matched against the input
  device name; find yours with `sudo evtest`.

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
- Two-finger tap, pinch, and other multi-touch gestures cannot work on
  single-touch eGalax-style controllers; that is a hardware limit, not a
  software gap. A USB mouse works alongside touch with no configuration.
- Needs `/dev/uinput` and event-device read access; the service runs as root
  for this reason. It is input-only and stays out of the delayed `pvrsrvkm`
  boot sequencing.

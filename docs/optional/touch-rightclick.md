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
`python3-evdev` from the existing apt cache (pass `--update` to refresh it
first), runs the built-in detector self-test, and enables/starts
`touch-rightclick.service`. It never reboots and touches nothing in the GPU,
desktop, or remote stacks.

Tuning (defaults suit the WS170120):

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

## Verify

1. `systemctl status touch-rightclick.service` is active; `journalctl -u
   touch-rightclick.service` shows the watched device and each emitted click.
2. Hold a finger still on the panel: the context menu appears after the
   deadline. Short taps and drags behave exactly as before.
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
  observes without grabbing, by design). The injected right-click wins for
  context menus, but a held press can also begin a drag/select in some apps.
  Prefer `tap-hold` when long-press selection matters to you.
- Two-finger tap, pinch, and other multi-touch gestures cannot work on
  single-touch eGalax-style controllers; that is a hardware limit, not a
  software gap. A USB mouse works alongside touch with no configuration.
- Needs `/dev/uinput` and event-device read access; the service runs as root
  for this reason. It is input-only and stays out of the delayed `pvrsrvkm`
  boot sequencing.

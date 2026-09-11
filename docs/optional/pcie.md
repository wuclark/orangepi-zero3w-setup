# Optional PCIe HAT support (experimental)

> Experimental, community-tested layer. Not part of the PowerVR reference
> stack. One hardware combination has been brought up on real hardware (see
> evidence below); every other PCIe card must be tested individually.

The Orange Pi Zero 3W exposes PCIe through its FFC connector and the A733
supports PCIe 3.0, but a Raspberry Pi 5–style PCIe HAT can appear completely
dead even when the Orange Pi PCIe root controller itself is enabled. On the
tested system Linux created the root bridge yet enumerated nothing below it,
because the stock Device Tree node lacked the external endpoint power/reset
GPIOs the Allwinner PCIe driver expects, and the Gen2 HAT never trained at the
requested Gen3 rate.

The fix is a small Device Tree overlay that adds those GPIOs and targets
Gen2, installed through the Armbian-style `user_overlays` mechanism.

## Tested boundary

```text
Board:  Orange Pi Zero 3W, Allwinner A733 / sun60iw2
Kernel: 6.6.98-vendor-sun60iw2
Boot:   Armbian-style /boot/armbianEnv.txt + user overlays
HAT:    Waveshare PCIe-to-M.2/USB HAT+ (ASMedia ASM1182e Gen2 PCIe switch
        + VIA VL805/806 USB 3 controller)
Link:   Gen2 x1, trained successfully
```

Reference: <https://www.waveshare.com/wiki/PCIe_TO_M.2_USB_HAT+>

Prerequisites: working Armbian boot with SSH, the PCIe FFC adapter/cable
path, the HAT (with its dedicated 5 V input powered when present), and
`device-tree-compiler`, `pciutils`, `usbutils` (the installer adds them from
the existing apt cache unless `--update` is passed). Root is required for
install/uninstall; status is read-only. This guide does not use Raspberry
Pi's `dtparam=pciex1` — that setting is specific to Raspberry Pi firmware and
does nothing on the Orange Pi.

Non-goals: no claim that every PCIe HAT works, no hot-plug support, no NVMe
performance tuning, no redistribution of the Orange Pi manual or schematic
(link to vendor documentation instead).

## Failure signature

Before the fix, `sudo lspci -nn` showed only the root bridge:

```text
00:00.0 PCI bridge [0604]: Device [1f6d:abcd] (rev 01)
```

with the link stuck at Gen1:

```text
LnkCap: Port #0, Speed 8GT/s, Width x1
LnkSta: Speed 2.5GT/s, Width x1
```

and `sudo dmesg | grep -Ei 'pcie|power-gpios|reset-gpios|speed change|speed of|link'`
reported:

```text
sunxi:pcie-6000000.pcie:[WARN]: Failed to get "power-gpios"
sunxi:pcie-6000000.pcie:[WARN]: Failed to get "reset-gpios"
sunxi:pcie-rc-6000000.pcie:[ERR]: Speed change timeout
sunxi:pcie-rc-6000000.pcie:[INFO]: PCIe speed of Gen1
```

That output is diagnostic, not "PCIe disabled": the controller was enabled
(`status = "okay"`), the root complex initialized, but the driver could not
sequence the endpoint and retraining failed.

## Inspect the live Device Tree

```bash
sudo apt install -y device-tree-compiler  # or let the installer handle it
sudo find /proc/device-tree/soc@3000000/pcie@6000000 -maxdepth 2 -type f -print
sudo dtc -I fs -O dts /proc/device-tree 2>/dev/null \
  | sed -n '/pcie@6000000 {/,/^                };/p'
```

The stock node requested `max-link-speed = <0x03>` (Gen3 x1) on the
`allwinner,sunxi-pcie-v300-rc` compatible, with internal `resets` /
`reset-names` for the controller itself — but no `reset-gpios` /
`power-gpios` for the external endpoint. Do not confuse the two: `resets`
drives internal controller lines, while `reset-gpios` drives the external
PCIe PERST# pin.

## GPIO mapping

From the OPI Zero 3W V1.2 schematic, cross-checked against the stock
`wake-gpios` (bank D pin 21) already present in the live tree:

```text
PD21 = PCIE-WAKEn    (stock, untouched)
PD22 = PCIE-PERSTn   (active low  -> flag 1)
PD23 = PCIE_PWREN_H  (active high -> flag 0)
```

Hence:

```text
reset-gpios = <&pio 3 22 1>;
power-gpios = <&pio 3 23 0>;
```

Numeric flags avoid `#include <dt-bindings/gpio/gpio.h>`: plain `dtc` does
not run the C preprocessor, so the include form fails with a parse error
unless the DTS is preprocessed separately. `1` is `GPIO_ACTIVE_LOW`,
`0` is `GPIO_ACTIVE_HIGH`.

## Install

Recommended (preserves existing `user_overlays` entries, backs up boot
config, validates the compiled overlay, never reboots):

```bash
sudo ./setup.sh pcie --install
# or: sudo make board-pcie-install
```

To refresh apt metadata first (default uses the existing cache):

```bash
sudo ./setup.sh pcie --install --update
```

What the installer writes:

```text
/boot/overlay-user/sun60iw2-pcie-gen2.dtbo   (compiled overlay, mode 0644)
/boot/armbianEnv.txt                         (merges user_overlays entry)
/boot/armbianEnv.txt.backup-before-sun60iw2-pcie-gen2-<timestamp>
```

The overlay source lives at `overlays/sun60iw2-pcie-gen2.dts`; the compiled
`.dtbo` is generated, never committed. Re-running install is idempotent.

Advanced (manual equivalent):

```bash
dtc -@ -I dts -O dtb \
  -o sun60iw2-pcie-gen2.dtbo overlays/sun60iw2-pcie-gen2.dts
sudo mkdir -p /boot/overlay-user
sudo cp sun60iw2-pcie-gen2.dtbo /boot/overlay-user/
# merge sun60iw2-pcie-gen2 into the existing user_overlays list, then:
cat /boot/armbianEnv.txt  # must contain user_overlays=...sun60iw2-pcie-gen2...
```

When decompiling the standalone `.dtbo`, `reset-gpios = <0xffffffff ...>`
plus a `__fixups__ { pio = ...; }` section is normal: the bootloader
resolves the `&pio` phandle against the base tree at apply time. A Gen2-only
first test (`max-link-speed = <2>` alone) changes the live tree but does not
enumerate the endpoint — both the speed target and the GPIOs are required.

## Cold boot (required)

PCIe is not hot-pluggable in this setup. After install:

```bash
sudo poweroff
```

Remove board power ~10 s with the FFC/HAT already connected (power the HAT
appropriately), then boot.

## Verify

```bash
make board-pcie-status
# or: ./scripts/board-pcie-status.sh
```

Live Device Tree (property order may vary):

```text
max-link-speed = <0x02>;
reset-gpios = <0x36 0x03 0x16 0x01>;   (bank D pin 22 = 0x16, active low)
power-gpios = <0x36 0x03 0x17 0x00>;   (bank D pin 23 = 0x17, active high)
wake-gpios = <0x36 0x03 0x15 0x00>;    (bank D pin 21 = 0x15)
status = "okay";
```

Kernel link success (missing-GPIO warnings gone):

```text
sunxi:pcie-rc-6000000.pcie:[INFO]: pcie link up success
sunxi:pcie-rc-6000000.pcie:[INFO]: PCIe speed of Gen2
```

Enumeration (`sudo lspci -nn`):

```text
00:00.0 PCI bridge [0604]: Device [1f6d:abcd] (rev 01)
01:00.0 PCI bridge [0604]: ASMedia Technology Inc. ASM1182e 2-Port PCIe x1 Gen2 Packet Switch [1b21:1182]
02:03.0 PCI bridge [0604]: ASMedia Technology Inc. ASM1182e 2-Port PCIe x1 Gen2 Packet Switch [1b21:1182]
02:07.0 PCI bridge [0604]: ASMedia Technology Inc. ASM1182e 2-Port PCIe x1 Gen2 Packet Switch [1b21:1182]
04:00.0 USB controller [0c03]: VIA Technologies, Inc. VL805/806 xHCI USB 3.0 Controller [1106:3483] (rev 01)
```

Tree (`sudo lspci -tv`):

```text
-[0000:00]---00.0-[01-ff]----00.0-[02-04]--+-03.0-[03]--
                                           \-07.0-[04]----00.0  VIA Technologies, Inc. VL805/806 xHCI USB 3.0 Controller
```

Then check the HAT's USB side (`lsusb -t`, `lsusb`; plug a mouse, keyboard,
or flash drive and watch `sudo dmesg -w`), and block devices
(`lsblk -o NAME,MODEL,SIZE,TRAN`). For a combined HAT with NVMe, install the
drive only after the switch itself enumerates, cold boot again, and look for
an NVMe endpoint (e.g. under the unused downstream bridge) plus
`/dev/nvme0n1` — confirm the device name before formatting anything.

## Rollback

If the system still boots:

```bash
sudo ./setup.sh pcie --uninstall   # or: sudo make board-pcie-uninstall
```

or restore the printed backup:

```bash
sudo cp /boot/armbianEnv.txt.backup-before-sun60iw2-pcie-gen2-<stamp> /boot/armbianEnv.txt
```

then `sudo poweroff`, cold boot. The `.dtbo` file may stay in
`/boot/overlay-user/` — it is inert unless referenced by `user_overlays`.
Delete it only for full cleanup:

```bash
sudo rm -f /boot/overlay-user/sun60iw2-pcie-gen2.dtbo
```

## Troubleshooting

- Only `00:00.0` in lspci: check dmesg for the missing-GPIO warnings; if
  present, the overlay did not apply — verify `grep user_overlays
  /boot/armbianEnv.txt`, `ls -l /boot/overlay-user/`, then cold boot (not
  just `reboot`).
- `dtc` include error: use the numeric flags from this guide instead of
  `#include <dt-bindings/gpio/gpio.h>` with raw `dtc`.
- Link stays Gen1: confirm `max-link-speed = <0x02>` in the live tree; if
  set, suspect FFC orientation/quality/length, endpoint power, adapter pin
  mapping, PERST# or reference-clock routing, or CLKREQ# compatibility.
- VL805/806 in lspci but no USB devices: that is a USB/xHCI driver issue,
  not a PCIe-link issue — check `lsusb -t` and `dmesg | grep -Ei 'xhci|usb'`.
- After a kernel upgrade, re-verify: upgrades may replace base DTBs and
  kernel-managed overlay directories. Re-check `uname -a`,
  `/boot/armbianEnv.txt`, the live PCIe properties, dmesg link lines, and
  `lspci -nn`. Treat `/boot/overlay-user/` content and the `user_overlays`
  entry as configuration to re-validate.

## Evidence and support scope

Observed on the test system: stock node enabled at Gen3 x1, missing
power/reset GPIO warnings, Gen1 fallback with speed-change timeout before;
live node at Gen2 with PD22/PD23 properties, warnings gone, Gen2 link-up,
ASM1182e switch and VL805/806 controller enumerated after.

To report another card, collect `make board-pcie-status` output plus
`uname -a` and the HAT/adapter/power details, sanitized per
`docs/development/evidence-format.md` (no secrets, host keys, or VNC
hashes). Different cards differ in power, reset timing, reference clock,
CLKREQ#/ASPM behavior, firmware, and lane/speed needs — test each one
individually before any support claim.

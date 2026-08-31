# Headless Armbian setup (legacy link)

The general SD-card and first-boot procedure moved to
[Prepare the SD card](../guide/00-prepare-sd-card.md) and
[First boot and Wi-Fi](../guide/01-first-boot-wifi.md). Keep using those pages
for new installations.

After SSH works, the base image installs no additional packages by default.
Choose optional software with:

```bash
cd ~/orangepi-zero3w-setup
sudo ./scripts/armbian-provision.sh
```

The PVR/GPU stack remains a separate, deliberate installation described in
[Fresh Armbian installation](fresh-armbian-install.md).

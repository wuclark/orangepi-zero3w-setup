# First boot and Wi-Fi

Complete [Prepare the SD card](00-prepare-sd-card.md) first. The Orange Pi
Zero 3W has no built-in Ethernet adapter, so the initial setup uses Armbian's
first-boot preset and the onboard Wi-Fi.

After boot, find the DHCP address or use mDNS:

```bash
ssh orangepi@orangepi.local
sudo rm -f /root/.not_logged_in_yet
hostnamectl
uname -a
ip addr
sudo ./setup.sh base --hostname op03W
```

The first-boot preset configures only Armbian's documented preset variables.
Set the hostname after login with the `--hostname` option shown above; the
preset generator does not attempt to encode hostname configuration.

Do not run GPU installation until the board reports the expected kernel and a
serial-console recovery path is available.

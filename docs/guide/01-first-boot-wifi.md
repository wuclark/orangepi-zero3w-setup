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
sudo ./setup.sh base
```

The first-boot preset configures only Armbian's documented preset variables.
The companion `/root/provisioning.sh` hook sets the hostname after the first
successful login. Verify it with `hostnamectl`, then remove the temporary
`/root/.not_logged_in_yet` and `/root/provisioning.sh` files if they remain.

Do not run GPU installation until the board reports the expected kernel and a
serial-console recovery path is available.

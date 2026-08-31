# First boot and Wi-Fi

The Orange Pi Zero 3W has no built-in Ethernet adapter, so the initial setup
uses Armbian's first-boot preset and the onboard Wi-Fi. Write the Armbian
Debian 13 vendor image to the SD card, then create the temporary preset:

```bash
sudo ./scripts/create-headless-preset.sh --root-mount /mnt/armbian-root
```

The preset writes `/root/.not_logged_in_yet` with the hostname, user, Wi-Fi
SSID, Wi-Fi key, DHCP, and country settings. It contains plaintext credentials;
keep it private and delete it after the first successful SSH login.

On Windows, use `windows/Prepare-HeadlessPreset.ps1`. On Linux, use the Bash
generator above. The scripts can also create a local file for copying to the
mounted root filesystem.

After boot, find the DHCP address or use mDNS:

```bash
ssh orangepi@orangepi.local
sudo rm -f /root/.not_logged_in_yet
sudo ./setup.sh base
```

Do not run GPU installation until the board reports the expected kernel and a
serial-console recovery path is available.

# Base system

The base setup is CLI-only and safe to rerun:

```bash
sudo ./setup.sh base
sudo ./setup.sh status
```

It validates the A733 board, records the selected user, and creates project
state under `/etc/orangepi-zero3w-setup/`. It does not run `apt update`, run a
full upgrade, install a GUI, enable VNC, or reboot.

Optional packages are installed only when requested:

```bash
sudo ./setup.sh packages
```

To refresh package metadata, explicitly request it:

```bash
sudo ./setup.sh packages --update
```

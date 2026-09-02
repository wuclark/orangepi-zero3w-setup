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

From the repository directory, the same foundation sequence is available as:

```bash
sudo make board-foundation
```

This runs `base`, the interactive `packages` menu, `core`, and `sources` in
that order. To run one step separately, use `make board-base`, `make
board-packages`, `make board-core`, or `make board-sources`. The package step
uses the existing apt cache unless its explicit update option is selected.

For a complete initial board setup, including GPU, VPU, and experimental NPU
installation, use:

```bash
sudo make board-initial-setup
```

This runs the foundation and acceleration installers in order without rebooting.
Reboot once afterward, then run `sudo make board-validation`. The NPU step still
requires its local test assets and remains experimental.

For the complete initial setup with the default XFCE/X11 desktop and x11vnc:

```bash
sudo make board-initial-setup-gui
```

This includes `board-initial-setup`, unmasks and enables LightDM, installs
XFCE/X11, and configures x11vnc. It prompts for the VNC password and does not
reboot. Reboot once afterward, then run `sudo make board-validation`.

To refresh package metadata, explicitly request it:

```bash
sudo ./setup.sh packages --update
```

## Docker and Docker Compose

Docker is optional and is not installed by the base command. To install
Debian's Docker Engine and Compose packages, run the package menu and choose
option `4`:

```bash
sudo ./setup.sh packages
```

The Docker option installs `docker.io` and `docker-compose` from the Armbian
Debian package sources. Refresh apt metadata first only when needed:

```bash
sudo ./setup.sh packages --update
```

Enable Docker and allow the regular login user to run it without `sudo`:

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out and back in so the group membership takes effect. Verify both services
before deploying an application:

```bash
docker version
docker compose version
```

Run a Compose application from the directory containing its
`compose.yaml` or `docker-compose.yml`:

```bash
docker compose up -d
docker compose ps
docker compose down
```

The Docker group grants root-equivalent access on the host. Use `sudo docker`
instead if that privilege should not be delegated to the regular user.

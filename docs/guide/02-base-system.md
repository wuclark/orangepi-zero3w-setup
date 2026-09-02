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
board-packages`, `make board-core`, or `make board-sources`. Source checkouts
are shallow by default; use `sudo make board-sources GIT_DEPTH=0` when full Git
history is required. The package step uses the existing apt cache unless its
explicit update option is selected.

For a complete initial board setup, including GPU, VPU, and experimental NPU
installation, use:

```bash
sudo make board-initial-setup
```

This runs base, packages, core, and the acceleration installers in order without
cloning the optional source trees or rebooting. Reboot once afterward, then run
`sudo make board-validation`. The NPU step still requires its local test assets
and remains experimental. Use `sudo make board-sources` separately when source
trees are needed for development or inspection.

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

Docker is optional and is not installed by the base command. On the board, use
`sudo make board-docker-install DOCKER_APT_UPDATE=1` to install the official
Docker Engine, Buildx, and Compose packages:

```bash
sudo make board-docker-install DOCKER_APT_UPDATE=1
```

Log in again so the Docker group is active, then run the repository verifier:

```bash
make board-docker-verify
```

The verifier checks the client and daemon, architecture, Compose, Buildx, and
an actual `hello-world` container. The installer enables Docker and adds the
selected login user to the `docker` group. If package metadata was refreshed
separately, omit `DOCKER_APT_UPDATE=1`; the default is not to run `apt update`.

For the older Debian package-menu path, choose option `4` from:

```bash
sudo ./setup.sh packages
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

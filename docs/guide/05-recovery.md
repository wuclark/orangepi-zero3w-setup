# Recovery and reset

Inspect the managed state with:

```bash
sudo ./setup.sh status
```

The project keeps configuration and state under
`/etc/orangepi-zero3w-setup/`; system configuration backups belong under
`/var/backups/orangepi-zero3w-setup/`.

Reset project-managed GUI and remote configuration without removing packages:

```bash
sudo ./setup.sh reset
```

Remove project-managed services and configuration while preserving vendor GPU
runtime/module files for recovery:

```bash
sudo ./setup.sh uninstall
```

Review packages manually before removing them. Keep serial/UART access
available for GPU work.

## Workspace backup and restore

The Git repository contains the scripts and documentation, but not the large
source images, proprietary SDK, generated vendor archives, or local credentials.
Use an external destination for these ignored files:

```bash
make backup-required BACKUP_DIR=/mnt/backup/orangepi-zero3w
make backup-cache BACKUP_DIR=/mnt/backup/orangepi-zero3w
make backup-sensitive BACKUP_DIR=/mnt/backup/orangepi-zero3w
```

The required set contains the Orange Pi NPU image, Radxa GPU/VPU image, Armbian
base image, AI SDK, matching kernel source, and supplied legacy vendor inputs.
The cache set contains generated userspace archives, NPU assets, VPU fixtures,
checksums, and derived SD images. The sensitive set contains
`not_logged_in_yet` and `provisioning.sh`; it is separate because those files
contain passwords and Wi-Fi credentials.

`make backup-all BACKUP_DIR=...` creates all three sets. Each set has a
`manifest.sha256` file and the backup root has `backup-info.txt`.

Restore selectively after verifying the destination:

```bash
make restore BACKUP_DIR=/mnt/backup/orangepi-zero3w RESTORE_SET=required
make restore BACKUP_DIR=/mnt/backup/orangepi-zero3w RESTORE_SET=cache
make restore BACKUP_DIR=/mnt/backup/orangepi-zero3w RESTORE_SET=sensitive
make restore BACKUP_DIR=/mnt/backup/orangepi-zero3w RESTORE_SET=all
```

Restore checks every selected manifest before copying and prompts before
overwriting repository files. Sensitive or unattended restores require
`RESTORE_FORCE=1`; keep the backup encrypted and never commit it.

## Full offline bundle

For a single portable bundle with the repo snapshot and everything above:

```bash
make fullbackup BACKUP_DIR=/mnt/usb/zero3w-bundle
make fullbackup BACKUP_DIR=/mnt/usb/zero3w-bundle INCLUDE_SENSITIVE=YES BUNDLE_COMPRESS=xz
```

With no `BACKUP_DIR` the target prints the required arguments and restore
instructions instead of guessing. Compression defaults to gzip. Restore with:

```bash
make fullrestore BACKUP_DIR=/mnt/usb/zero3w-bundle
make fullrestore BACKUP_DIR=/mnt/usb/zero3w-bundle RESTORE_SET=cache
```

New images or vendor files under `work/images/`, `vendor-files/`,
`vendor-root/`, `work/vendor-output/`, or `work/sources/` are picked up
automatically by pattern (see `scripts/create-offline-bundle.sh`).

## Fresh-machine rebuild from a bundle

The bundle holds every file input but not the host itself. Only host
prerequisites need the network (`sudo apt install -y git docker.io curl
unzip`, plus Docker group setup); everything else runs offline from the
bundle, including the repository checkout itself via `repo.bundle`:

```bash
# Fully offline checkout: full git history, no GitHub access needed.
git clone /mnt/usb/zero3w-bundle/repo.bundle orangepi-zero3w-setup
cd orangepi-zero3w-setup
# Retarget origin for later pulls (config-only, works offline; git pull
# works once the machine is online again).
git remote set-url origin https://github.com/wuclark/orangepi-zero3w-setup.git
make fullrestore BACKUP_DIR=/mnt/usb/zero3w-bundle
make test
make docker-toolchain
make newsd
make validate
```

(If the machine is online, `git clone
https://github.com/wuclark/orangepi-zero3w-setup.git` first and restore the
bundle on top works the same way.)

Notes:

- `repo.bundle` carries every branch and tag (`git bundle create --all`), so
  `git log`, `git pull`, and `git switch` behave exactly like a GitHub clone
  once origin is retargeted. `make fullrestore` also retargets origin
  automatically when it finds a bundle-cloned checkout.
- `work/sources/a733_npu_driver` and `build-pvrsrvkm/linux-orangepi` restore
  with their `.git` directories intact; `make kernel-source` then reuses them.
- Docker daemon images are not files and are never bundled. The bundle holds
  their sources (`docker/` in the snapshot, the ACUITY zip), so rebuild the
  toolchain with `make docker-toolchain`. Reload ACUITY with
  `make npu-acuity-image-load` only when regenerating NPU goldens — the
  goldens themselves already restore from `work/vendor-output/`.
- Restored derived preloaded images are reused automatically; `make newsd`
  cleans and rebuilds them from the restored inputs when you want a fresh run.

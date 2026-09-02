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

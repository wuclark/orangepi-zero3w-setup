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

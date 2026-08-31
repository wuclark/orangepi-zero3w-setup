# Optional GPU acceleration

The PowerVR DDK and out-of-tree `pvrsrvkm` module are optional and supported
only on the reference Armbian Debian 13 vendor kernel. Read the existing
[archive workflow](archive-workflow.md), [architecture](../../reference/architecture.md), and
[troubleshooting guide](../../reference/troubleshooting.md) before installation.

```bash
sudo ./setup.sh gpu
```

The GPU command uses the existing apt cache. Add `--update` only when you
explicitly want to refresh package metadata:

```bash
sudo ./setup.sh gpu --update
```

This path is safety-sensitive: the tested kernel requires delayed module
loading. Do not shorten or replace that ordering without a board reboot test,
UART access, and a recovery plan.

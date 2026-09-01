# Hardware references

The following board documents were consulted during the 2026 bring-up:

- *OrangePi Zero3W A733 User Manual*, version 1.0 (281 pages)
- *OPI ZERO 3W V1_2 Schematic Diagram*, board schematic version 1.2 (18 pages)

They confirm the Allwinner A733 platform, PowerVR-class GPU integration, HDMI
2.0 display path, PCIe/USB high-speed interface, 5 V/3 A board power target,
and a documented 12 GB memory configuration. The schematic identifies distinct
GPU power rails and the PCIe clock, reset, wake, and power-enable signals.

These hardware facts do not prove userspace or kernel ABI compatibility. The
software support claim in this repository remains limited to the reference
manifest and recorded real-board tests. The PDFs are not bundled in this source
archive; obtain them from Orange Pi or another authorized source.

## Verified CPU topology

The reference Orange Pi board reports eight CPUs in two frequency clusters:

```text
CPU 0-5: 1.794 GHz maximum — lower-frequency Cortex-A55 cluster
CPU 6-7: 2.002 GHz maximum — higher-frequency Cortex-A76 cluster
```

CPU numbering is platform-specific; verify a replacement image with
`lscpu -e=CPU,CORE,SOCKET,MAXMHZ` before applying affinity settings. A workload
that should leave one lower-frequency CPU available for maintenance can use
CPUs `0-4,6-7`, leaving CPU 5 unused by that workload. Do not use
`isolcpus` or pin `sshd` as part of the default setup; SSH normally needs no
dedicated CPU.

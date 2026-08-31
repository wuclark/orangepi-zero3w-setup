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

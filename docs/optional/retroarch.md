# Retro Gaming / RetroArch

The optional RetroArch feature installs the Debian 13 RetroArch package,
repository-provided `libretro-*` cores, assets, Vulkan tools, and ALSA tools.
It is not a claim of a complete official RetroPie installation. EmulationStation
is optional and is installed only when the configured Debian repositories offer
it.

Install and validate it on the Orange Pi after the X11/PowerVR layer is ready:

```bash
sudo make board-retroarch-install
sudo make board-retroarch-verify
```

To install advanced cores, use only packages exposed by the existing Debian
APT sources and/or provide legally obtained ARM64 Libretro `.so` files:

```bash
sudo make board-retroarch-advanced
sudo make board-retroarch-advanced RETROARCH_CORE_FILES='/path/to/pcsx.so /path/to/flycast.so'
sudo make board-retroarch-download-advanced
sudo make board-retroarch-core-check
```

The supplied files are checked as ARM64 and installed alongside Debian cores
under `/usr/lib/aarch64-linux-gnu/libretro`. The advanced package names tried are repository-available
variants of PCSX, Mupen64Plus/Parallel-N64, PPSSPP, and Flycast. Unavailable
packages are not fabricated or downloaded from an untrusted source. The
download target explicitly fetches five corresponding Linux aarch64 cores
from the official Libretro buildbot, validates each ZIP, and validates the
ARM64 payload before installation. It uses the mutable `latest` buildbot path;
for reproducible deployments, set `RETROARCH_CORE_BASE_URL` to a dated or
privately mirrored directory that you have reviewed.

`board-retroarch-core-check` checks the five advanced cores for ARM64 format,
unresolved shared-library dependencies, and bounded RetroArch loading evidence.
Missing cores are reported as warnings; run the download target first when all
five are wanted.

The installer configures the selected non-root desktop user and creates the
`RetroArch (PowerVR Vulkan)` application entry and the
`/usr/local/bin/retroarch-powervr` launcher. The launcher sets the board's
Vulkan ICD and explicitly unsets `LD_LIBRARY_PATH`. Never globally point
`LD_LIBRARY_PATH` at `/opt/pvr-ddk-24.2/lib`: the proprietary directory contains
libraries such as `libOpenCL.so.1` that can override Debian libraries and crash
RetroArch or FFmpeg.

The feature uses direct ALSA playback. The default is `audio_device = "default"`;
if the default device cannot play, try:

```bash
sudo make board-retroarch-audio-test
sudo make board-retroarch-audio-test RETROARCH_AUDIO_DEVICE=plughw:CARD=allwinnerhdmi,DEV=0
sudo make board-retroarch-audio-auto
```

The test is bounded and can also be stopped with Ctrl-C. MIDI is disabled to
avoid irrelevant `/dev/snd/seq` errors. Group changes require a new login or
reboot. A local desktop session is preferred for the X11 smoke test; SSH
without X11 authorization can make RetroArch report a `null` Vulkan context
even when `vulkaninfo` correctly sees PowerVR.

`board-retroarch-audio-auto` backs up the configuration, tests `default` and
then the explicit HDMI `plughw` device, and keeps the first working device.
Use `board-audio-status` to inspect cards without playing anything, and
`board-display-status` to inspect HDMI and USB-C DP connectors.

For repeated no-display hardware testing, run:

```bash
sudo make board-stability-test STABILITY_MINUTES=30
```

This repeats the GPU/VPU/NPU headless workloads and records temperatures and
new matching kernel messages. `STABILITY_STORAGE=yes` also runs the storage
benchmark in each iteration and writes temporary data to the storage device;
use it only when deliberate SD-card write testing is intended.

The default interval between iterations is 30 seconds. Change it when testing
interactively, for example `STABILITY_INTERVAL_SECONDS=5`; use zero only for
continuous testing because it increases sustained load and heat.

Each iteration prints an ASCII temperature snapshot and, when `gnuplot-nox` is
installed, a historical ASCII line graph from the CSV collected so far. The
test also saves a CSV file, a text report, and a PNG temperature graph beside
the report. Install the graph tool with:

```bash
sudo make board-system-benchmark-deps
```

If downloaded cores do not show friendly names, refresh Debian's core
information package and, when available, RetroArch's Core Info Files:

```bash
sudo apt install --reinstall -y libretro-core-info
```

In RetroArch, use `Main Menu -> Online Updater -> Update Core Info Files`.

The expected hardware validation is:

```bash
env -u LD_LIBRARY_PATH \
  VK_ICD_FILENAMES=/opt/pvr-ddk-24.2/vulkan/img_icd.json \
  vulkaninfo --summary
sudo make board-retroarch-verify
```

The verifier accepts harmless Wayland/DBus messages, requires the expected
PowerVR GPU and X11 Vulkan context when display access is available, and warns
instead of failing for an HDMI ALSA stream that cannot complete. Debian's
RetroArch build may not provide a Core Downloader; install the discovered
repository cores during setup instead. The available set may not include
GameCube or PS2 cores. Do not download random precompiled cores or copyrighted
ROMs.

For this board, use Snes9x or BSNES Mercury Performance rather than the
Accuracy build. The advanced download installs PCSX-ReARMed for PlayStation,
Beetle PSX HW for optional hardware-rendered PlayStation testing, ParaLLEl N64,
PPSSPP, and Flycast. Do not silently install unverified precompiled cores.

Core names and systems:

| Core | Systems |
| --- | --- |
| Nestopia | NES |
| Snes9x | SNES |
| BSNES Mercury Performance | SNES; heavier than Snes9x, preferred over the Accuracy build on this board |
| Genesis Plus GX | Genesis/Mega Drive, Master System, Game Gear |
| Gambatte | Game Boy, Game Boy Color |
| mGBA | Game Boy Advance |
| DeSmuME | Nintendo DS |
| Beetle VB | Virtual Boy |
| Beetle WonderSwan | WonderSwan |
| PCSX-ReARMed | PlayStation; best first performance choice on this ARM board |
| Beetle PSX HW | PlayStation; optional Vulkan hardware-rendering test |
| ParaLLEl N64 | Nintendo 64; start at 1x with conservative options |
| PPSSPP | PSP; start at 1x PSP resolution |
| Flycast | Dreamcast |

Advanced-core notes:

- PPSSPP may need its core system files. If the Debian build exposes the Core
  System Files Downloader, use it to install `PPSSPP.zip`; otherwise obtain
  only the required support files from the core's official documentation.
- PlayStation compatibility is best tested first with PCSX-ReARMed. Beetle PSX
  HW can be tried later with Vulkan and a 2x internal resolution.
- PlayStation BIOS files, when required by the core, belong in
  `~/.config/retroarch/system`, for example `scph5501.bin`, `scph7001.bin`, or
  `scph101.bin`. Use legally obtained files.
- Dreamcast BIOS files, when used, belong in
  `~/.config/retroarch/system/dc/dc_boot.bin` and
  `~/.config/retroarch/system/dc/dc_flash.bin`.
- ParaLLEl N64 is the downloaded AArch64 option. Start with its parallel RDP
  and RSP plugins, 1x upscaling, and anti-aliasing off. The proprietary GPU
  driver may not expose every feature its Vulkan renderer requests.

To inspect unresolved shared-library dependencies after an advanced download:

```bash
for core in /usr/lib/aarch64-linux-gnu/libretro/{pcsx_rearmed,mednafen_psx_hw,parallel_n64,ppsspp,flycast}_libretro.so; do
  [ -f "$core" ] || continue
  echo "===== $core ====="
  ldd "$core" | grep 'not found' || echo 'Dependencies resolved'
done
```

Never run this setup with `/opt/pvr-ddk-24.2/lib` in `LD_LIBRARY_PATH`.

Keep ROMs in a user-owned directory such as `~/roms`, and place legally owned
system BIOS files only where the core documentation specifies. Configure a
controller from RetroArch's input settings. The installer does not distribute
ROMs or BIOS files.

`sudo make board-retroarch-repair` restores the newest timestamped
`retroarch.cfg.previous.*` backup and reapplies the safe PowerVR/ALSA settings.
`sudo make board-retroarch-uninstall` asks before removing the feature's
tracked packages and launcher. ROMs, saves, and configuration are retained by
default.

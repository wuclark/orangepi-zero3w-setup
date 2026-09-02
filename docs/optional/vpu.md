# Optional VPU acceleration

VPU support is separate from the base setup and GPU. The board workflow
installs the extracted Cedar/OpenMAX userspace, including `/etc/cedarc.conf`,
and verifies real H.264 and H.265 decode through GStreamer.

```bash
sudo ./setup.sh vpu --install
sudo ./setup.sh vpu --verify
```

The equivalent commands from the repository directory are:

```bash
make board-vpu-precheck
make board-vpu-install
make board-vpu-verify
make board-vpu-decode-test
```

Verification uses the locally generated 720p H.264/H.265 MP4 samples under
`testdata/videos/` when available, runs the explicit `omxh264dec` and
`omxhevcvideodec` pipelines into `fakesink`, and records checksums and logs
under `/var/log/orangepi-zero3w-setup/`. If the generated files are absent, the
test prompts whether to generate them locally or download the pinned legacy
samples under `/var/lib/orangepi-zero3w-setup/vpu-test-media`. The pipeline is
headless and does not require X11.

### VPU validation TODO

The current test validates that Cedar opens the stream and reaches EOS. The
planned stronger validation is:

1. Generate reproducible local H.264 and H.265 MP4 samples with FFmpeg,
   covering 720p and 1080p, 30 and 60 fps, suitable H.264 profiles, H.265
   streams, and controlled keyframe intervals.
2. Run every sample through the matching Cedar hardware decoder and require
   the device-open and EOS checks.
3. Decode the same samples through a software reference decoder.
4. Convert hardware and software frames to the same raw format, such as
   `yuv420p`, and compare them with PSNR/SSIM rather than requiring exact byte
   equality, since decoder implementations may round pixels differently.
5. Record sample hashes, codec parameters, decoder logs, frame counts, and
   comparison results in the board evidence.

The generated media should remain local test input and must not be committed
to Git unless a separately documented reproducibility policy is adopted.

The generated files can be uploaded individually to a pinned GitHub Release
after generation:

```bash
make release-vpu-test-videos VPU_TESTDATA_TAG=vpu-testdata-v1
```

This requires `gh auth login` and is an explicit publishing operation. A board
can retrieve and verify those individual assets with:

```bash
make board-vpu-fetch-videos VPU_TESTDATA_TAG=vpu-testdata-v1
```

The fetch script verifies the release's `SHA256SUMS` before the decode test
uses the files. Release fixtures are pinned by tag; do not use a mutable
`latest` URL for evidence.

The VPU installer stages archives privately, installs FFmpeg, GStreamer tools,
and parser plugins without running `apt update`, installs Cedar configuration and
udev rules, reloads the device rules, and keeps timestamped backups. Its
repository-owned udev rule gives members of the `video` group access to
`/dev/cedar_dev*` for desktop applications such as Terminology. It does not
install the GPU or NPU layers.

The proprietary archives, firmware, and generated test media remain excluded
from Git. Real-board evidence must still include the kernel, device nodes,
runtime versions, exact sample workload, successful output, and reboot results.

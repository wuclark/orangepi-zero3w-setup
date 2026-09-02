# Synthetic VPU test videos

These videos are generated locally with FFmpeg's `lavfi` sources. They contain
animated, multicolor content and burned-in frame numbers and timecodes, making
frame drops, duplication, reordering, and visible color-plane errors easier to
spot. The MP4 and `.md5` files are generated test data and are intentionally
ignored by Git.

Regenerate the complete matrix from the repository root:

```bash
./scripts/gen_test_videos.sh
```

Regenerate one source or overwrite existing files:

```bash
./scripts/gen_test_videos.sh --only mandelbrot --force
```

The generator creates four sources (`mandelbrot`, `testsrc`, `rgbtestsrc`, and
`life`) at 1280x720/30 fps and 1920x1080/60 fps in both H.264 and H.265, plus
one side-by-side H.264 combo file. Each video has a neighboring `framemd5`
file. Exact `framemd5` matches are useful only for lossless/passthrough decode;
if the VPU performs scaling or colorspace conversion, compare decoded output
with FFmpeg's `ssim` or `psnr` filters instead.

On the Orange Pi, generate the files after the VPU layer is installed:

```bash
make board-vpu-generate-videos
```

The existing VPU decode smoke test prefers the generated H.264 and H.265 files.
If they are absent, it prompts whether to generate them or download the legacy
samples. The burned-in overlays provide a quick visual check, while frame
counts and `ssim`/`psnr` provide programmatic follow-up.

To publish the individual files as GitHub Release assets, first generate the
complete set and then run the explicit release target:

```bash
./scripts/gen_test_videos.sh --force
make release-vpu-test-videos VPU_TESTDATA_TAG=vpu-testdata-v1
```

The release contains each MP4 and its neighboring `.md5` file separately,
plus `SHA256SUMS`. On a board, retrieve a pinned release with:

```bash
make board-vpu-fetch-videos VPU_TESTDATA_TAG=vpu-testdata-v1
```

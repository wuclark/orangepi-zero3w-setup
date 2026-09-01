# Userspace archive workflow

`pvr-userspace.tar.gz` and `vpu-userspace.tar.gz` are the preferred interchange
format because Linux tar archives preserve symlinks, filenames, and directory
layout while crossing Windows. Do not extract and repackage them in Explorer.

## Generate the archives

Generate the archives in this repository from locally supplied, verified source
root filesystems:

```bash
./scripts/extract-vendor-userspace-docker.sh
```

The extractor produces:

```text
pvr-userspace.tar.gz
vpu-userspace.tar.gz
npu-userspace.tar.gz
```

On Windows, use `windows/Extract-VendorUserspace.ps1` through WSL2. Mount or
unpack the source images before running it; image mounting differs between
Windows, WSL2, and native Linux.

## WSL2 work layout and preparation

Keep source images and generated proprietary archives under the ignored
repository-local `work/` directory:

```text
work/
├── images/                 # original verified .img/.xz/.7z files
└── vendor-output/          # generated archives and manifests
```

For WSL2 Ubuntu, copy the verified images into `work/images/` and run:

```bash
./scripts/extract-vendor-userspace-docker.sh
```

The Docker helper discovers the first ext4 partition in each image, mounts both
partitions read-only inside a privileged temporary container, and removes the
mounts afterward. It supports `.img`, `.img.xz`, and `.img.7z` inputs. It
recognizes names such as:

```text
radxa-a733_bullseye_kde_r2.output_512.img.xz
Orangepizero3w_1.0.0_ubuntu_jammy_desktop_xfce_linux6.6.98.7z
```

The wrapper refuses to guess when multiple candidates exist and does not treat
arbitrary similarly named images as supported. Select another image explicitly
with `GPU_VPU_IMAGE` and `NPU_IMAGE`; that path is experimental until the
package manifests, runtime paths, hashes, and generated archive are checked:

```bash
GPU_VPU_IMAGE=./work/images/radxa.img \
NPU_IMAGE=./work/images/orangepi.img.xz \
./scripts/extract-vendor-userspace-docker.sh
```

These are third-party/proprietary outputs. Review their licenses and keep them
out of this Git repository.

## Transfer from Windows

For a newly prepared SD card, the archives may instead be copied to the
mounted card before first boot under
`/home/orangepi/orangepi-zero3w-setup/vendor-files/`. See the [SD-card
preparation guide](../../guide/00-prepare-sd-card.md#optionally-copy-vendor-archives-before-first-boot)
for the required ownership and permissions. In either workflow, copy the
tarballs unchanged and do not extract them into the target root filesystem.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\Copy-VendorArchives.ps1 `
  -SourceDirectory "C:\path\to\orangepi-zero3w-setup\work\vendor-output" `
  -BoardHost "orangepizero3w.local" `
  -SshUser "orangepi"
```

The script copies the archive bytes unchanged into `vendor-files/`. It does not
extract them on Windows.

## Inspect without installing

```bash
tar -tzf vendor-files/pvr-userspace.tar.gz | less
stage=$(mktemp -d)
./scripts/prepare-vendor-archives.sh \
  --pvr-tarball vendor-files/pvr-userspace.tar.gz \
  --vpu-tarball vendor-files/vpu-userspace.tar.gz \
  --output "$stage"
find "$stage" -maxdepth 4 -type f | sort | less
```

The validator rejects absolute paths, `..` traversal, unsafe link targets,
invalid gzip/tar data, unexpected wrapper directories, and missing required PVR
components. It extracts with ownership and mode restoration disabled.

## Install

```bash
sudo ./install.sh
```

GPU userspace is installed under `/opt/pvr-ddk-24.2`. Optional Cedar/GStreamer
OMX VPU files are installed into their package-compatible `/usr` and `/etc`
runtime paths from an explicit allowlist, with timestamped backups. The installer still
builds or validates `pvrsrvkm.ko` separately because the archives do not supply
a module matched to the running kernel.

```bash
sudo ./install.sh --pvr-tarball /path/pvr-userspace.tar.gz
sudo ./install.sh --without-vpu
sudo ./install.sh --vendor-root /path/to/extracted/root  # legacy/debug
```

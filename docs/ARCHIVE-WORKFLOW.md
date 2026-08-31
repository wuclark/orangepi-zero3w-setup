# Userspace archive workflow

`pvr-userspace.tar.gz` and `vpu-userspace.tar.gz` are the preferred interchange
format because Linux tar archives preserve symlinks, filenames, and directory
layout while crossing Windows. Do not extract and repackage them in Explorer.

## Generate the archives

Follow the external `OrangePiZero3W-GPU-VPU` project to create:

```text
pvr-userspace.tar.gz
vpu-userspace.tar.gz
```

These are third-party/proprietary outputs. Review their licenses and keep them
out of this Git repository.

## Transfer from Windows

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\Copy-VendorArchives.ps1 `
  -SourceDirectory "C:\Users\YOU\Downloads\OrangePiZero3W-GPU-VPU\output" `
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

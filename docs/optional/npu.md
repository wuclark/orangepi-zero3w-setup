# Optional NPU acceleration

NPU support is separate from the base setup, GPU, and VPU. The repository does
not currently claim a tested NPU runtime. Use the diagnostic placeholder:

```bash
sudo ./setup.sh npu --status
```

Do not install or document a runtime as supported until real-board evidence
records the kernel, module, firmware/runtime versions, device nodes, sample
workload, and successful output. Proprietary archives and firmware remain
excluded from Git.

## Implementation TODO: cross-platform userspace extraction

The planned workflow is to generate an `npu-userspace.tar.gz` archive from a
legally obtained, checksum-verified Orange Pi image. The archive may be
created on native Linux, WSL2, or another Linux environment; Windows should
provide a PowerShell wrapper for selecting the image and copying the result.
The Orange Pi will consume the archive through the normal vendor-files
workflow after SSH is available.

Keep extraction and installation separate:

1. A host-side extractor mounts the Orange Pi image read-only in a private
   temporary directory and copies only an allowlisted NPU runtime.
2. The existing archive validator checks paths, links, archive format, and
   required files without extracting over `/`.
3. A future board-side installer stages privately, verifies architecture and
   runtime/driver compatibility, then installs with timestamped backups.
4. `scripts/collect-diagnostics.sh` records `/dev/vipcore`, module details,
   runtime versions, and a reproducible inference smoke test.

The implementation must determine and document the exact VIPLite/Vivante
runtime files, configuration, firmware requirements, and whether model
compiler tools belong in a separate SDK archive. It must not copy `vipcore.ko`
or claim support merely because `/dev/vipcore` exists. Validate against the
Orange Pi image and the target board's running kernel/driver ABI first.

Planned inputs and outputs:

```text
Host input:  orangepi-zero3w-image.img[.xz|.7z]
Host output: npu-userspace.tar.gz + manifest.sha256
Board input: vendor-files/npu-userspace.tar.gz
Board test:  /dev/vipcore + pinned VIPLite workload
```

# Optional NPU acceleration

NPU support is separate from the base setup, GPU, and VPU. The repository
provides an experimental runtime/test path when both generated NPU archives
are present. Start with:

```bash
sudo ./setup.sh npu --status
```

On an image built with the AI SDK test bundle:

```bash
make board-npu-precheck
make board-npu-install
make board-npu-verify
```

Do not install or document a runtime as supported until real-board evidence
records the kernel, module, firmware/runtime versions, device nodes, sample
workload, and successful output. Proprietary archives and firmware remain
excluded from Git.

## Cross-platform userspace extraction

The repository now provides a host-side extractor for all three userspace
layers. GPU/VPU normally come from a Radxa A733 root filesystem and NPU from
the matching Orange Pi root filesystem:

```bash
./scripts/extract-vendor-userspace-docker.sh
```

Use `--source-root` when all components are in one test root. The inputs must
be mounted or unpacked, checksum-verified filesystems. The extractor runs on
native Linux or WSL2; Windows has a wrapper at
`windows/Extract-VendorUserspace.ps1`.

Keep extraction and installation separate:

1. The host-side extractor reads mounted source roots and copies only
   allowlisted GPU, VPU, and NPU runtime files.
2. The existing archive validator checks paths, links, archive format, and
   required files without extracting over `/`.
3. A future board-side installer stages privately, verifies architecture and
   runtime/driver compatibility, then installs with timestamped backups.
4. `scripts/collect-diagnostics.sh` records `/dev/vipcore`, module details,
   runtime versions, and a reproducible inference smoke test.

The extractor currently targets the VIPLite runtime libraries, including
`libVIPhal.so` and `libNBGlinker.so`, while the AI SDK staging step supplies the
board test assets. The allowlist must be checked against
the exact Orange Pi image before release. It must not copy `vipcore.ko` or
claim support merely because `/dev/vipcore` exists. Validate against the Orange
Pi image and the target board's running kernel/driver ABI first.

Planned inputs and outputs:

```text
Host input:  mounted/extracted Radxa and Orange Pi root filesystems
Host output: pvr-userspace.tar.gz, vpu-userspace.tar.gz, npu-userspace.tar.gz
Board input: vendor-files/npu-userspace.tar.gz
Board test:  /dev/vipcore + pinned VIPLite workload
```

When `work/images/ai-sdk.tar.gz` is available, `make newsd` stages a small
`npu-test-assets.tar.gz` alongside the NPU userspace archive. It contains the
AArch64 `vpm_run` source, VIPLite headers, one test NBG and input data, plus a
YOLOv5 NBG and sample image; it does not contain the full SDK. The runner is
compiled and tested on the target board, so this remains experimental until
the workload returns success on the target kernel and driver.

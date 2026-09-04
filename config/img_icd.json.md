# `config/img_icd.json` sidecar

## Purpose

This file is the Vulkan Installable Client Driver (ICD) manifest staged for the
PowerVR userspace DDK. It tells the Vulkan loader which vendor library provides
the implementation.

## Consumer

The system Vulkan loader reads the manifest when it scans the installed ICD
directory. The setup flow installs it alongside
`/opt/pvr-ddk-24.2/lib/libVK_IMG.so`. The architecture and isolation rationale
is described in [`docs/reference/architecture.md`](../docs/reference/architecture.md).

## Exact schema constraints

The document must remain valid JSON with this structure:

- top-level `file_format_version` string;
- top-level `ICD` object;
- `ICD.library_path` absolute path to the PowerVR `libVK_IMG.so` library;
- `ICD.api_version` Vulkan API version supported by that DDK.

Do not add comments, trailing commas, shell substitutions, or environment
variables. JSON has no portable comment syntax, and the Vulkan loader expects a
machine-readable manifest.

## Safe changes

Change `library_path` only when the installed DDK path changes as part of a
matching userspace installation. Change `api_version` only when the DDK and
the tested reference stack change together; it must match the actual library,
not merely the Debian loader. Do not point this manifest at Mesa or make the
vendor path global for unrelated applications.

## Verification

Run the host checks:

```bash
./tests/static-checks.sh
python3 -m json.tool config/img_icd.json >/dev/null
```

On the target board, after installing the matching DDK and rebooting through
the documented delayed `pvrsrvkm` load, run `sudo ./scripts/verify.sh` and
confirm the Vulkan summary reports the tested PowerVR implementation.

## Why comments are impossible

JSON does not permit comments while this file must remain directly consumable
by the Vulkan loader. This sidecar carries the human-maintained purpose,
consumer, schema, compatibility boundary, safe extension points, and
verification instructions without changing the machine-valid manifest.

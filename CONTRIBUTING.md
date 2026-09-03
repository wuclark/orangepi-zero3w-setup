# Contributing

Reports from other boards are welcome, but compatibility claims must include:

- board model and RAM size;
- distribution and release;
- exact kernel version;
- module `vermagic`;
- DDK version;
- BVNC from dmesg;
- `scripts/collect-diagnostics.sh` output with public IPs or other sensitive information removed;
- results from `scripts/verify.sh`.

Do not submit proprietary binaries unless you have verified redistribution rights. Prefer extraction instructions, hashes and source references.

Shell scripts invoked directly by the Makefile or setup commands must be
committed with executable mode. After adding one, run `chmod 755 path/to/script.sh`
and verify it with `git ls-files -s path/to/script.sh` or the static checks.

## Documentation standard

Every maintained executable script must have enough nearby documentation and
comments to teach a new maintainer how it works. At minimum, document its
purpose, accepted inputs and environment variables, outputs and evidence,
system or root-level writes, failure behavior, safety boundaries, known
limitations, and the reason for any non-obvious implementation decision.
Non-obvious configuration files and Make targets follow the same standard.
Keep trivial code self-explanatory, but explain decisions that affect boot
ordering, ABI compatibility, proprietary-library isolation, data safety,
recovery, or hardware support. Use a guide under `docs/` when the explanation
does not belong in the source file, and link the source comment to that guide.

When extending a component, update its documentation in the same change. A
feature is not complete if a maintainer can run it but cannot understand its
inputs, side effects, recovery path, or safe ways to extend it.

For shell scripts, this compact header is a useful starting point; omit fields
that truly do not apply and link to the relevant `docs/` guide for detail:

```bash
# Purpose:
# Board/OS/architecture/kernel assumptions:
# Inputs and environment:
# Requires (commands/packages/services/devices):
# Permissions and sudo requirements:
# Writes and side effects:
# Idempotency and repeat-run behavior:
# Downloads and provenance:
# Cleanup, rollback, and recovery:
# Outputs, exit behavior, logs, and evidence:
# Security and privacy:
# Verification commands:
# Examples and non-goals:
```

Configuration files and Make targets should provide the equivalent information
in comments or linked documentation. In particular, record why a setting is
safe for this board, what compatibility boundary it reflects, and how a future
maintainer can change it without weakening recovery or hardware safety.

Kernel panics or boot failures must be treated as safety-critical regressions. Keep delayed module loading as the default until a tested kernel-specific alternative exists.

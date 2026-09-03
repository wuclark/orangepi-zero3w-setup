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

Kernel panics or boot failures must be treated as safety-critical regressions. Keep delayed module loading as the default until a tested kernel-specific alternative exists.

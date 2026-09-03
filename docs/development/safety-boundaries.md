# Safety boundaries

| Boundary | Rules |
| --- | --- |
| Host image building | Mount source images read-only, use the pinned Docker toolchain, stage private output under `work/`, and never extract untrusted content over `/`. |
| Image deployment | Treat first-boot images as credential-bearing; validate checksum and partition layout, identify the SD device independently, and warn that writing overwrites it. |
| Board installation | Use one acceleration layer at a time, preserve timestamped backups, keep PowerVR module loading delayed, and require ABI/reboot checks before GPU workloads. |
| Evidence and access | Keep diagnostics read-only where possible, bind remote services to localhost/SSH tunnels, and sanitize credentials, IPs, VNC hashes, and host keys. |

High-risk operations are package installation, writes below `/opt`, `/usr`,
`/etc`, `/var`, image writes, systemd target/service changes, module loading,
storage benchmarks, and secret restore. Each must document confirmation,
rollback, or recovery behavior.

Never add `/opt/pvr-ddk-24.2/lib` to global `LD_LIBRARY_PATH`, linker
configuration, or a user profile. The scoped launcher is the compatibility
boundary that prevents PVR `libOpenCL.so.1` from overriding system libraries.

Read-only checks must not silently repair a system. Validation failures should
identify the relevant installer or recovery command instead.

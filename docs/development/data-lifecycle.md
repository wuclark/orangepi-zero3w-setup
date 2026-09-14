# Data lifecycle

The project separates reproducible source inputs, generated artifacts,
board-installed files, and evidence so derived or proprietary data is not
mistaken for source code.

```text
source images + AI SDK
        → host extraction / Docker
        → allowlisted vendor archives
        → preloaded image
        → first-boot image
        → confirmed SD card
        → board installation layers
        → validation and benchmark evidence
        → sanitized board reports
```

Tracked source is repository code, configuration, manifests, documentation, and
tests. Private or ignored data includes source images, proprietary archives and
firmware, generated images, credentials, ROMs/BIOS files, board logs containing
secrets, and downloaded RetroArch core caches.

Rebuildable data includes extracted archives, generated VPU fixtures, derived
images, benchmark output, and board reports. Hard-to-replace inputs include the
exact source images, AI SDK, proprietary source/vendor files, credentials, and
legally obtained game support files.

Every new artifact must be classified as tracked source, private input,
rebuildable output, installed system state, or evidence. Add it to the correct
backup set and Git exclusion policy before introducing it to a workflow.

## Board replay manifest

`/etc/orangepi-zero3w-setup/manifest.json` records every repo-managed board
layer as a replayable receipt so a working board can be rebuilt on another
board or after a reinstall:

```json
{"schema": 1, "board": "xunlong,orangepi-zero3w ...", "created": "...",
 "updated": "...",
 "steps": {"desktop.plasma": {"replay": "sudo make desktop-plasma", "ts": "..."},
           "desktop.active": {"replay": "sudo make switch-plasma", "ts": "..."}}}
```

Recorded components: `foundation.*` (base, packages, core, sources),
`acceleration.*` (gpu, vpu, npu), `desktop.*` (each installed profile plus
`desktop.active` for the selected session), `remote.*`, `touch`, `retroarch`,
`pcie`, `docker`. `make board-manifest` shows the manifest;
`make board-replay` dry-runs it in dependency order;
`make board-replay-execute` runs it (never reboots; reboot manually after
acceleration install and desktop switches, then validate). `board-report`
bundles a manifest copy as evidence.

Rules for contributors:

1. Every installer that changes board state must call
   `manifest_record <step-key> <replay-command>` from `scripts/lib.sh` on
   success, and delete its key on uninstall (`manifest_delete` /
   `manifest_delete_prefix`). Reinstalling overwrites the same key, so the
   manifest always reflects current state.
2. The replay command must be the exact documented entrypoint
   (`sudo make ...` / `sudo ./setup.sh ...`); replay runs it verbatim.
3. Never record secrets: no passwords, hashes, keys, or tokens. Replay
   re-prompts or regenerates them.
4. New components also need a rank in `scripts/board-replay.sh`, a row in
   `docs/development/make-target-index.md` when targets change, and a
   changelog entry.

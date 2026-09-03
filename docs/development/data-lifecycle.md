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

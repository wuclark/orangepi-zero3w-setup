#!/usr/bin/env bash
# Purpose: Show the board replay manifest (recorded installers) in human form.
# Platform: Orange Pi board; runs as any user with read access to the manifest.
# Inputs: /etc/orangepi-zero3w-setup/manifest.json; optional --json for raw output.
# Writes: stdout only.
# Safety: strictly read-only; installs, modifies, or reboots nothing.
# Repeat behavior: safe to run repeatedly.
# Recovery: no changes are made.
# Verification: compare against board-status output and the raw manifest file.
# Documentation: docs/development/data-lifecycle.md
set -Eeuo pipefail

MANIFEST=/etc/orangepi-zero3w-setup/manifest.json
RAW=no
while (($#)); do
    case "$1" in
        --json) RAW=yes; shift ;;
        -h|--help) echo "Usage: $0 [--json]"; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -f $MANIFEST ]] || { echo "No board manifest yet ($MANIFEST absent). Install a layer to start recording."; exit 0; }
if [[ $RAW == yes ]]; then
    cat -- "$MANIFEST"
    exit 0
fi
python3 - "$MANIFEST" <<'EOF'
import json, sys
with open(sys.argv[1]) as f:
    manifest = json.load(f)
print("Board:   %s" % manifest.get("board", "unknown"))
print("Created: %s" % manifest.get("created"))
print("Updated: %s" % manifest.get("updated"))
print("")
steps = manifest.get("steps", {})
for key in sorted(steps):
    print("%-22s %s  (%s)" % (key, steps[key].get("replay"), steps[key].get("ts")))
print("")
print("Replay this board with: sudo make board-replay        (dry run)")
print("                          sudo make board-replay-execute  (runs it)")
EOF

#!/usr/bin/env bash
# Purpose: Replay the board manifest on a fresh board (dry run by default).
# Platform: Orange Pi board with this repository checked out at the repo root.
# Inputs: /etc/orangepi-zero3w-setup/manifest.json; --execute actually runs.
# Writes: dry run writes nothing; --execute runs each recorded replay command
#   in dependency order from the repository root.
# Safety: dry run is the default and never changes the system. Execution runs
#   only recorded installer commands (never secrets; replay re-prompts for
#   passwords), stops on the first failure, and never reboots: reboot manually
#   after acceleration install and after switching desktops, as usual.
# Repeat behavior: installers are idempotent, so replaying is safe to repeat.
# Recovery: fix the failing step and rerun; completed steps simply reinstall.
# Verification: dry-run output first, then board-status and board-validation.
# Documentation: docs/development/data-lifecycle.md
set -Eeuo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST=/etc/orangepi-zero3w-setup/manifest.json
EXECUTE=no
while (($#)); do
    case "$1" in
        --execute) EXECUTE=yes; shift ;;
        -h|--help) echo "Usage: $0 [--execute]"; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -f $MANIFEST ]] || { echo "ERROR: no board manifest ($MANIFEST absent); nothing to replay." >&2; exit 1; }
export MANIFEST REPO_ROOT EXECUTE
python3 - <<'EOF'
import json, os, subprocess, sys
with open(os.environ["MANIFEST"]) as f:
    manifest = json.load(f)
steps = manifest.get("steps", {})
if not steps:
    print("Manifest has no recorded steps; nothing to replay.")
    sys.exit(0)

def rank(key):
    fixed = ["foundation.base", "foundation.packages", "foundation.core",
             "foundation.sources", "acceleration.gpu", "acceleration.vpu",
             "acceleration.npu"]
    if key in fixed:
        return (0, fixed.index(key))
    if key.startswith("desktop.") and key != "desktop.active":
        return (1, key)
    if key == "desktop.active":
        return (2, key)
    if key.startswith("remote."):
        return (3, key)
    tail = ["touch", "retroarch", "pcie", "docker"]
    if key in tail:
        return (4, tail.index(key))
    return (5, key)

ordered = sorted(steps, key=rank)
execute = os.environ.get("EXECUTE") == "yes"
root = os.environ["REPO_ROOT"]
print("Replaying %d recorded step(s) from %s in dependency order%s."
      % (len(ordered), os.environ["MANIFEST"],
         "" if execute else " (dry run; pass --execute to run)"))
for i, key in enumerate(ordered, 1):
    cmd = steps[key]["replay"]
    print("[%d/%d] %s: %s" % (i, len(ordered), key, cmd))
    if execute:
        result = subprocess.run(cmd, shell=True, cwd=root)
        if result.returncode != 0:
            print("FAILED at step %s; fix it and rerun to continue." % key,
                  file=sys.stderr)
            sys.exit(result.returncode)
if execute:
    print("Replay complete. Reboot manually after acceleration install and "
          "after switching desktops, then run board-validation.")
else:
    print("Dry run only; nothing was changed.")
EOF

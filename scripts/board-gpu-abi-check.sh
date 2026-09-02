#!/usr/bin/env bash
set -Eeuo pipefail

MODULE=/opt/pvrsrvkm.ko
EXPECTED_KERNEL=6.6.98-vendor-sun60iw2
PASS=0; FAIL=0
pass() { printf 'PASS  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }

echo "PowerVR kernel/module ABI check: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
running_kernel=$(uname -r)
printf 'Running kernel: %s\n' "$running_kernel"
if [[ $running_kernel == "$EXPECTED_KERNEL" ]]; then pass "expected kernel $EXPECTED_KERNEL";
else fail "kernel is $running_kernel; expected $EXPECTED_KERNEL"; fi

if [[ -f $MODULE ]]; then
    module_name=$(modinfo -F name "$MODULE" 2>/dev/null || true)
    vermagic=$(modinfo -F vermagic "$MODULE" 2>/dev/null || true)
    [[ $module_name == pvrsrvkm ]] && pass 'installed module name is pvrsrvkm' || fail "installed module name is ${module_name:-unreadable}"
    [[ $vermagic == "$running_kernel"* ]] && pass "module vermagic matches $running_kernel" || fail "module vermagic '${vermagic:-unreadable}' does not match $running_kernel"
else
    fail "installed module is missing: $MODULE"
fi

loaded_path=$(readlink -f /sys/module/pvrsrvkm 2>/dev/null || true)
[[ -n $loaded_path ]] && pass 'pvrsrvkm is currently loaded' || fail 'pvrsrvkm is not currently loaded'
[[ -f /lib/modules/$running_kernel/build/Makefile ]] \
    && pass 'matching kernel headers are installed' \
    || fail "matching kernel headers are missing: /lib/modules/$running_kernel/build/Makefile"
systemctl is-enabled --quiet pvr-late-load.service 2>/dev/null \
    && pass 'delayed PowerVR service is enabled' \
    || fail 'delayed PowerVR service is not enabled'
for firmware in /usr/lib/firmware/rgx.fw.36.56.104.183 /usr/lib/firmware/rgx.sh.36.56.104.183; do
    [[ -r $firmware ]] && pass "firmware present: $(basename "$firmware")" \
        || fail "firmware missing: $firmware"
done

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
if ((FAIL > 0)); then
    echo 'ACTION: do not use the GPU stack or reboot into a changed kernel until the ABI mismatch is resolved.'
    echo 'ACTION: rebuild the module for the running kernel, then rerun this check.'
fi
((FAIL == 0))

#!/usr/bin/env bash
set -u

PASS=0
FAIL=0
WARN=0

pass() { printf 'PASS  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf 'WARN  %s\n' "$*"; WARN=$((WARN + 1)); }

if systemctl is-active --quiet pvr-late-load.service; then
    pass "Delayed PowerVR service is active"
else
    fail "Delayed PowerVR service is not active"
fi

if lsmod | grep -q '^pvrsrvkm '; then pass "pvrsrvkm is loaded"; else fail "pvrsrvkm is not loaded"; fi

for node in /dev/dri/card0 /dev/dri/card1 /dev/dri/renderD128; do
    if [[ -e $node ]]; then pass "$node exists"; else fail "$node is missing"; fi
done

for firmware in /usr/lib/firmware/rgx.fw.36.56.104.183 /usr/lib/firmware/rgx.sh.36.56.104.183; do
    if [[ -r $firmware ]]; then pass "$firmware is readable"; else fail "$firmware is missing"; fi
done

for library in \
    /opt/pvr-ddk-24.2/lib/libVK_IMG.so \
    /opt/pvr-ddk-24.2/lib/libpvr_mesa_wsi.so \
    /opt/pvr-ddk-24.2/lib/libGLESv2_PVR_MESA.so \
    /opt/pvr-ddk-24.2/mesa/dri/pvr_dri.so
do
    if [[ -e $library ]]; then pass "$library exists"; else fail "$library is missing"; fi
done

if command -v vulkaninfo >/dev/null 2>&1; then
    VK_OUTPUT=$(env -u DISPLAY VK_ICD_FILENAMES=/etc/vulkan/icd.d/img_icd.json vulkaninfo --summary 2>&1)
    if grep -q 'PowerVR B-Series BXM-4-64 MC1' <<<"$VK_OUTPUT"; then
        pass "Headless Vulkan enumerates the PowerVR GPU"
    else
        fail "Headless Vulkan did not enumerate PowerVR"
        printf '%s\n' "$VK_OUTPUT"
    fi
else
    fail "vulkaninfo is not installed"
fi

if [[ -S /tmp/.X11-unix/X0 ]]; then
    pass "Xorg display :0 exists"
    if command -v xdpyinfo >/dev/null 2>&1; then
        EXTENSIONS=$(DISPLAY=:0 xdpyinfo 2>/dev/null)
        for extension in DRI2 DRI3 Present; do
            if grep -Eq "^[[:space:]]+$extension[[:space:]]*$" <<<"$EXTENSIONS"; then
                pass "X11 exposes $extension"
            else
                fail "X11 does not expose $extension"
            fi
        done
    fi
else
    warn "Xorg display :0 is not running"
fi

if command -v eglinfo >/dev/null 2>&1; then
    EGL_OUTPUT=$(LD_LIBRARY_PATH=/opt/pvr-ddk-24.2/mesa/lib:/opt/pvr-ddk-24.2/lib LIBGL_DRIVERS_PATH=/opt/pvr-ddk-24.2/mesa/dri eglinfo -B 2>&1)
    if grep -q 'OpenGL ES profile renderer: PowerVR B-Series BXM-4-64' <<<"$EGL_OUTPUT"; then
        pass "EGL/OpenGL ES uses PowerVR"
    else
        warn "EGL did not report the PowerVR renderer"
    fi
fi

if [[ -S /tmp/.X11-unix/X0 ]] && command -v glxinfo >/dev/null 2>&1; then
    GLX_OUTPUT=$(DISPLAY=:0 glxinfo -B 2>&1 || true)
    if grep -q 'llvmpipe' <<<"$GLX_OUTPUT"; then
        warn "X11 GLX is using llvmpipe software rendering"
    elif grep -qi 'PowerVR' <<<"$GLX_OUTPUT"; then
        pass "X11 GLX reports PowerVR"
    else
        warn "X11 GLX renderer could not be confirmed"
    fi
fi

printf '\nSummary: %d passed, %d warnings, %d failed\n' "$PASS" "$WARN" "$FAIL"
((FAIL == 0))

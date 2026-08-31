# Manifests

`reference-stack.env` records the known-good compatibility tuple.

Before publishing a tested release, generate hashes for user-supplied proprietary components locally without committing those components:

```bash
sha256sum \
  /opt/pvrsrvkm.ko \
  /usr/lib/firmware/rgx.fw.36.56.104.183 \
  /usr/lib/firmware/rgx.sh.36.56.104.183 \
  /opt/pvr-ddk-24.2/lib/libVK_IMG.so.24.2.6603887 \
  /opt/pvr-ddk-24.2/lib/libpvr_dri_support.so.24.2.6603887 \
  /opt/pvr-ddk-24.2/lib/libGLESv2_PVR_MESA.so.24.2.6603887
```

Publish the hashes and source package identification, not the proprietary files themselves, unless redistribution permission is confirmed.


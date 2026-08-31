# Third-party components

This repository contains installer code and configuration only.

It does not grant rights to, and should not directly redistribute, the proprietary Imagination Technologies PowerVR DDK, firmware, or vendor kernel module. Users must obtain those components from a source whose license permits their use.

Expected third-party components include:

- Imagination Technologies PowerVR DDK 24.2 userspace libraries
- `pvrsrvkm` kernel module matching the running vendor kernel
- RGX firmware matching BVNC `36.56.104.183`
- Mesa-based integration libraries included in the vendor graphics package

Debian packages installed by the scripts remain subject to their respective Debian package licenses.

Before publishing binary releases, review the license shipped with the source package and obtain permission where required. A source-only installer that extracts user-supplied files is the default supported distribution model.

Source locations, versions, and known archive checksums are recorded in
[`docs/vendor-sources.md`](docs/vendor-sources.md).

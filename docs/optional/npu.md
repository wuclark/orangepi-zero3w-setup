# Optional NPU acceleration

NPU support is separate from the base setup, GPU, and VPU. The repository does
not currently claim a tested NPU runtime. Use the diagnostic placeholder:

```bash
sudo ./setup.sh npu --status
```

Do not install or document a runtime as supported until real-board evidence
records the kernel, module, firmware/runtime versions, device nodes, sample
workload, and successful output. Proprietary archives and firmware remain
excluded from Git.

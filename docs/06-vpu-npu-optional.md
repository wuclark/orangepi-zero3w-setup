# Optional VPU and NPU

VPU and NPU support are separate from the base setup and GPU. The repository
does not currently claim a tested NPU runtime. Use the diagnostic placeholder:

```bash
sudo ./setup.sh npu --status
```

Do not install or document a runtime as supported until real-board evidence
records the kernel, module, firmware/runtime versions, device nodes, sample
workload, and successful output. Proprietary archives and firmware remain
excluded from Git.

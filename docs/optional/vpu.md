# Optional VPU acceleration

VPU support is separate from the base setup and GPU. The repository does not
currently claim a tested VPU media runtime. Use the diagnostic placeholder:

```bash
sudo ./setup.sh vpu --status
```

Do not install or document a runtime as supported until real-board evidence
records the kernel, modules, firmware/runtime versions, device nodes, sample
workload, and successful output. Proprietary archives and firmware remain
excluded from Git.

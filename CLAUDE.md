# Claude Code project instructions

Follow `AGENTS.md` as the canonical agent policy. Start each task by reading it
and `docs/DEVELOPMENT.md`. Plan before modifying installer, systemd, Xorg, boot,
or kernel-module code. Do not claim hardware validation from container tests.

Useful local checks:

```bash
./tests/static-checks.sh
./tests/test-archives.sh
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
git diff --check
```

Keep proprietary outputs outside Git. Do not weaken `.gitignore` safeguards.

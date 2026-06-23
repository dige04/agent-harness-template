---
name: dev-local-setup
description: Scaffold a one-command `dev-local` launcher for any codebase — investigate its services, ports, and infra, then generate a single `scripts/dev-local.sh` (up/down/status/logs/restart) plus a short doc. Use when someone says "set up dev-local", "make a one-command dev launcher", "I want one script to start this repo", "scaffold dev-local for this project".
---

# dev-local-setup

This skill executes the procedure in `playbooks/dev-local-setup.md`. That playbook is the
runtime-neutral source of truth; this file is the thin Claude wrapper.

When invoked, read `playbooks/dev-local-setup.md` and follow it end to end:
1. Investigate the repo (services, ports, infra, first-run steps, env files) — don't guess.
2. Generate `scripts/dev-local.sh` from `playbooks/assets/dev-local.template.sh`, then
   `chmod +x` and `bash -n` it; verify the read-only `status` path. Do NOT run `up`.
3. Write a short discoverable doc, then hand the user the exact `up` command and URLs.

Generate and syntax-check only — never start servers or print secrets.

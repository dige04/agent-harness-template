---
name: setup-codebase-harness
description: Master skill — set up the full agent harness for any repo so an agent can work it reliably: legible (map-not-manual docs + custom lints), executable (one-command dev stack), verifiable (e2e gate + verify-before-ship loop), plus commit hygiene and entropy control. Use when onboarding a new/unfamiliar codebase to agent-driven development — "set up the harness", "make this repo agent-ready", "harness this codebase".
user_invocable: true
---

# setup-codebase-harness

Master orchestration skill. It makes a repo legible, executable, and verifiable by running
the suite of playbooks (the runtime-neutral source of truth) incrementally and depth-first:

- Executable → `playbooks/dev-local-setup.md` (one-command local stack).
- Verifiable → `playbooks/e2e-setup.md` (the e2e gate) + `playbooks/pr.md` (verify-before-
  ship loop).
- Legible / brain layer → `loops/ARCHITECTURE.md` and `loops/BOUNDARY.md` for the
  knowledge-base model; slim the root agent doc to a map and push depth into `docs/`.

Order: dev-local → e2e + pr, then custom lints and commit hygiene as the repo matures.
Assess what already exists per pillar; build the one missing capability and use it to unlock
the next. Don't boil the ocean.

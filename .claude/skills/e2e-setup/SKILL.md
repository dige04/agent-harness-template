---
name: e2e-setup
description: Set up an end-to-end test suite that is a trustworthy per-PR gate — real flows over bypass, a reusable auth/session helper, layered client→server→product assertions, video+trace evidence, sandbox-only external services. Use when a repo has no e2e (or weak e2e) and you want system-level tests — "set up e2e", "add end-to-end tests", "scaffold a test gate".
---

# e2e-setup

This skill executes the procedure in `playbooks/e2e-setup.md`. That playbook is the
runtime-neutral source of truth; this file is the thin Claude wrapper.

When invoked, read `playbooks/e2e-setup.md` and follow it end to end: stand the app up
reproducibly (see `playbooks/dev-local-setup.md`), pick the framework, explore the flow
live, then crystallize a small deterministic set of critical-journey specs with a reusable
session helper, layered assertions, and video/trace evidence. Drive real flows (never
bypass); guard hard against live credentials; triage red tests before "fixing" them.

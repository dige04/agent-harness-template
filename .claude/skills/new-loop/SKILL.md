---
name: new-loop
description: Spin up a new loop (domain) in this knowledge base — gather its charter, scaffold loops/domains/<loop>/README.md, ensure the loops/signals/ + loops/docs/ substrate exists, then do ONE real test run and record it in the loop README's Timeline and in loops/LOG.md. Use when the user says "set up a new loop", "create a domain", "start a new beat/workstream", or names a recurring job they want the agent to own.
---

# new-loop

This skill executes the procedure in `playbooks/new-loop.md`. That playbook is the
runtime-neutral source of truth; this file is the thin Claude wrapper.

When invoked, read `playbooks/new-loop.md` and follow it end to end. In short:
1. Gather the loop's charter (name, goal, cadence, what it consumes/produces, tools/data).
2. Ensure the substrate exists (`loops/signals/`, `loops/docs/`, `loops/domains/`,
   `loops/LOG.md`) and scaffold `loops/domains/<name>/README.md`.
3. Do ONE real test run, then record it in the loop README's `## Timeline` and in
   `loops/LOG.md`.
4. Report the charter, the run result, any gaps, and how to re-run.

Read `loops/ARCHITECTURE.md` and `loops/BOUNDARY.md` first for the knowledge-base model.

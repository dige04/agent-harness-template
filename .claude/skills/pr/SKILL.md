---
name: pr
description: Prove the feature you just built actually works — an independent reviewer drives the real app — then open a pull request with the proof. Use when a change is ready to ship in any repo — "open a PR", "ship this", "raise a PR", "/pr". Never opens a PR until the feature is verified.
user_invocable: true
---

# pr

This skill executes the procedure in `playbooks/pr.md`. That playbook is the
runtime-neutral source of truth; this file is the thin Claude wrapper.

When invoked, read `playbooks/pr.md` and follow it end to end:
1. Preconditions: on a branch, changes committed.
2. Bring up the stack once via the repo's dev launcher.
3. Verify the FEATURE first — delegate to a fresh read-only verifier sub-agent that drives
   the running app and judges observed vs expected; fix and re-verify (cap ~3 rounds).
4. Run the codified regression sweep yourself (type-check, lint, unit, e2e).
5. Open the PR leading with the feature proof and a reviewable link to the recording.

Proof, not claims — never open a PR before the feature is verified.

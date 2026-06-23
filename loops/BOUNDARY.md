---
title: Loop layer ↔ Harness boundary
type: decision
status: adopted
domain: [meta]
---

# Boundary — the loop layer and the harness are one system, not two

This repo runs **two complementary operating layers**. They must never duplicate each other.
This doc is the contract: **one home per concept.** When in doubt, this file decides.

## The two layers

| | **Loop layer** (`loops/`) — brain + memory | **Harness layer** (`docs/`, `harness-cli`, `harness.db`) — hands + receipts |
|---|---|---|
| Role | **Direction & cross-run memory** | **Task governance & proof** |
| Answers | *What* should we work on, and *why*? | *How* did this get done, and is it *proven*? |
| Horizon | Across runs; compounds over time | One task / story at a time |
| Substrate | Markdown + frontmatter in git (diffable, agent-writable) | A CLI over durable records (SQLite) + policy docs |
| Granularity | Loops (domains), signals, knowledge docs | Intake → story → trace → decision → backlog |

The brain decides direction and accumulates evidence; the hands execute and prove. A loop that
ships code **flows through** the harness — it never reimplements it.

## One home per concept

| Concept | Canonical home | The other layer |
|---|---|---|
| **Product / market evidence** (a user pain, a feature gap, an idea, an observation) | `loops/signals/` (`kind: signal`, deduped, frequency-counted) | — |
| **Durable analysis / learnings** (how something works, a worked-through analysis, a thing you learned) | `loops/docs/` (`kind: doc`) | — |
| **Decisions** (architecture, scope, risk, a choice you'd want a rationale for) | `docs/decisions/` + recorded via `harness-cli decision` | A loop `doc` may *summarize or link* a decision; the durable record lives in the harness |
| **Shipping code** (committed engineering work) | a **story** in the harness (`harness-cli story add`) — **not** a loop `task` | The owning loop's `## Backlog` links the story id; it does not become a loop `task` kind |
| **Proof / validation status** (unit / integration / e2e, the validation ladder) | the harness — `harness-cli query matrix` | A loop's `LOG.md` entry *links* the proof; it never restates it |
| **Tooling / harness friction** (a confusing rule, a missing command, a repeated manual step) | the harness backlog (`harness-cli backlog add`) | A loop may *notice* it, but files it here — not as a product signal |
| **Human activity feed** ("what happened lately, one line each") | `loops/LOG.md` | Complementary to traces — `LOG.md` is for humans skimming; the trace is the structured record |

## When a loop ships code — the end-to-end flow

```
loop run surfaces evidence        →  loops/signals/<slug>.md  (or bumps frequency)
loop decides to act               →  loop README ## Backlog line
work is real engineering          →  harness-cli intake + story add  (the harness owns it)
implement + prove                 →  ship the change, drive the real app, regression sweep, open a PR
record proof + outcome            →  harness-cli story update / verify + trace
close the loop                    →  loops/LOG.md entry (links the PR + the trace id)
                                      + the loop README ## Timeline line
```

Nothing reaches the default branch without a human merge. Anything touching **auth, authorization,
data ownership, API shape, deploy/compose config, or validation requirements** is **high-risk**:
confirm with the human and record a decision before shipping.

## Quick test ("which layer?")

- *Is it about WHAT to work on and WHY (the product, users, market)?* → **loop layer.**
- *Is it about proving a specific task got done correctly?* → **harness layer** (the loop links the proof, never restates it).
- *Does it change behavior, architecture, or risk?* → **harness decision** (a loop `doc` may link it).
- *Is it about how the agent works the repo (a missing command, a confusing rule)?* → **harness backlog / friction.**
- *Is it "what we did, for a human to skim"?* → `loops/LOG.md`.

If a concept seems to want two homes, it's modeled wrong — re-read this table.

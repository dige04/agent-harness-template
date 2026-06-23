# agent-harness-template

An internally-owned, **agent-neutral** (AGENTS.md-first) template that installs a complete
agent operating system into any repo — greenfield or existing — via one installer.

It merges two layers: the **harness** (proof / receipts — a Rust CLI over a SQLite durable
layer plus a `docs/` system-of-record) and the **loops** brain (direction / memory — a
markdown knowledge base under `loops/`). `loops/BOUNDARY.md` is the contract that keeps them
from duplicating each other.

**To install into a target repo:** run `scripts/setup.sh` (from inside this template, or
remotely). Then `scripts/doctor.sh` validates the result.

See the design spec: `docs/superpowers/specs/2026-06-23-merged-agent-template-design.md`.

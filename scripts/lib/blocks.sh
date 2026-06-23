#!/usr/bin/env bash
render_harness_block() {
  cat <<'EOF'
<!-- HARNESS:BEGIN -->
## Harness (proof / receipts)
This repo uses the Rust harness for task governance and proof. Before work, read:
`docs/HARNESS.md`, `docs/FEATURE_INTAKE.md`, `docs/CONTEXT_RULES.md`, `docs/TRACE_SPEC.md`, `docs/TOOL_REGISTRY.md`.
Operate the durable layer with `scripts/bin/harness-cli` (e.g. `scripts/bin/harness-cli query matrix`).
<!-- HARNESS:END -->
EOF
}
render_loops_block() {
  cat <<'EOF'
<!-- LOOPS:BEGIN -->
## Loops (brain / memory)
Strategic memory lives under `loops/`. Read `loops/ARCHITECTURE.md` for the knowledge-base model
and `loops/BOUNDARY.md` for which layer owns which concept. Reusable procedures are in `playbooks/`.
<!-- LOOPS:END -->
EOF
}

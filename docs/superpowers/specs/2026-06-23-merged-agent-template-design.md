# Design: Merged Agent-Neutral Harness + Loop Template

- **Date:** 2026-06-23
- **Status:** Approved (design); pending spec review → implementation plan
- **Repo (deliverable):** `/Users/hieudinh/Documents/experiments/agent-harness-template`
- **Owner:** Hieu Dinh
- **Source systems (analyzed):**
  - `repository-harness` (MIT, Hoang Nguyen) — `/Users/hieudinh/Documents/experiments/repository-harness`, CLI `0.1.10`
  - `loop-engineer-template` (no license, AI Builder Club / Jason Zhou) — `/Users/hieudinh/Documents/experiments/loop-engineer-template`

## 1. Goal

Combine the two systems into **one internally-owned template** that drops a complete
agent operating system into **any project** (greenfield or existing) via a single
`setup.sh`. The template is **agent-neutral and AGENTS.md-first**; Claude Code support is
one optional runtime profile, not the core.

The two layers and their contract are unchanged from the proven francais.vn deployment:

- **Harness layer (hands + receipts)** — task governance and proof. A Rust CLI over a
  SQLite durable layer (`intake → story → trace → decision → backlog`), plus a `docs/`
  system-of-record. Answers *"how did this task get done, and is it proven?"*
- **Loop layer (brain + memory)** — direction and cross-run memory. A markdown knowledge
  base (`signals`, `docs`, `domains`) under `loops/`. Answers *"what should we work on, and
  why?"*
- **`loops/BOUNDARY.md`** — the one-home-per-concept contract that keeps the two from
  duplicating each other.

This generalizes francais.vn's layout and fixes the gaps the Codex audit found there
(loop layer uncommitted, CLI stale at `0.1.9`/schema 4, platform binary tracked in git).

## 2. Decisions (locked)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Distribution model | **Owned template + merge-installer** | One repo we maintain; `setup.sh` installs into new *and* existing repos via marked-block merge. Manual upstream curation (no auto-sync). |
| 2 | CLI binary sourcing | **Re-publish under our own releases** | Vendor `crates/` + release CI into the template; `setup.sh` downloads the per-platform binary (checksum-verified) from our GitHub releases. |
| 3 | Claude-locked skills/workflow | **Neutral playbooks + optional Claude profile** | `playbooks/*.md` are the agent-neutral source of truth (referenced by AGENTS.md); `.claude/` is a thin wrapper for slash-command ergonomics. |
| 4 | v1 build scope | **Lean install + `doctor`** | `setup.sh` + `doctor.sh` only. Defer `update`/manifest re-sync and Windows `.ps1` parity to v2. |
| 5 | Loop-layer licensing | **Internal-only** | No public redistribution, so a direct fork+strip of the unlicensed loop layer is acceptable. Retain the harness's MIT notice via `NOTICE`. |

## 3. Architecture

### 3.1 Layout the template installs into a target repo

```
<target-repo>/
├── AGENTS.md            # primary agent contract: project prose + 2 managed blocks
├── CLAUDE.md            # thin bridge "@AGENTS.md" — only when --claude
├── docs/                # HARNESS layer (hands + receipts)
│   ├── HARNESS.md  FEATURE_INTAKE.md  CONTEXT_RULES.md  TRACE_SPEC.md
│   │                    GLOSSARY.md  TOOL_REGISTRY.md  ARCHITECTURE.md
│   ├── templates/       # decision / story / spec-intake / validation-report
│   ├── product/         # EMPTY (README only) — project-owned
│   ├── stories/         # EMPTY (README only) — project-owned
│   └── decisions/       # EMPTY (README only) — project-owned
├── loops/               # LOOP layer (brain + memory), namespaced to dodge docs/ collision
│   ├── ARCHITECTURE.md  BOUNDARY.md  LOG.md
│   ├── signals/README.md   # schema only
│   ├── docs/README.md      # schema only
│   └── domains/README.md   # schema only
├── playbooks/           # agent-neutral procedures (source of truth for the loop skills)
│   ├── new-loop.md  dev-local-setup.md  e2e-setup.md  pr.md  ship-change.md
├── .claude/             # OPTIONAL profile (installed with --claude)
│   ├── skills/*/SKILL.md     # thin wrappers that point at playbooks/
│   └── workflows/ship-change.js
├── scripts/
│   ├── bin/harness-cli       # downloaded per-platform; GITIGNORED
│   ├── schema/*.sql          # version-controlled migrations
│   ├── setup.sh  doctor.sh
│   └── harness-cli-release-tag   # pins the CLI version
├── .gitignore           # union-merged
└── NOTICE               # retains harness MIT copyright
```

### 3.2 Template-source-only (NOT shipped to targets)

The template repo additionally contains the machinery to build/publish the CLI:

```
crates/harness-cli/                      # vendored Rust source (re-pointed identity)
.github/workflows/harness-cli-release.yml # tag-triggered multi-platform build + checksums
```

These two are **not** part of the installed payload (inherited `scripts/README.md` rule).

**One installer, two run-modes.** `scripts/setup.sh` is the single installer (the adapted
`install-harness.sh`). It runs either *from inside the template repo* (copies vendor-managed
files from the checkout into a target) or *remotely* (curls them from the template repo). A
copy of `setup.sh` + `doctor.sh` is also laid into the target's `scripts/` so the project can
re-run setup (to pull refreshed vendor-managed files) and health-check without the template
repo present. `crates/` and the release workflow never ship.

### 3.3 File ownership classes

Safe install/merge depends on classifying every file (this is the Codex-plan insight; a
plain copy or `--merge` can't update managed files without drift or clobbering):

- **Vendor-managed** (overwritten on re-install/update): `docs/*` policy docs,
  `scripts/schema/*.sql`, `playbooks/*`, the `.claude/` profile, `loops/*/README.md`
  schemas, `setup.sh`, `doctor.sh`.
- **Generated / merge-managed** (marked-block surgery; surrounding prose preserved):
  `AGENTS.md`, `CLAUDE.md`, `.gitignore`.
- **Project-owned** (never touched after first create): `docs/product/*`, `docs/stories/*`,
  `docs/decisions/*`, all content under `loops/{signals,docs,domains}/` except the README
  schemas, and the project-custom section of `AGENTS.md`.
- **Generated, never committed**: `scripts/bin/harness-cli`, `harness.db` (+ `-wal`/`-shm`).

### 3.4 AGENTS.md-first entrypoint (two managed blocks)

```
# Agent Instructions
<project-custom prose — project-owned, never overwritten>

<!-- HARNESS:BEGIN -->
…pointer to docs/ system-of-record (HARNESS.md, FEATURE_INTAKE.md, CONTEXT_RULES.md,
   TRACE_SPEC.md, TOOL_REGISTRY.md) + `scripts/bin/harness-cli query matrix`…
<!-- HARNESS:END -->

<!-- LOOPS:BEGIN -->
…pointer to loops/ KB model + loops/BOUNDARY.md + playbooks/…
<!-- LOOPS:END -->
```

- The installer re-injects **each block independently** and idempotently (awk surgery,
  inherited from the harness installer; extended with a second `LOOPS` region).
- `CLAUDE.md` (only with `--claude`) is a thin bridge that `@AGENTS.md` imports it, because
  Claude Code auto-loads `CLAUDE.md` but not `AGENTS.md`. No other Claude-specifics live
  outside the `.claude/` profile.
- **Single-source the block text.** The harness today triplicates its shim across
  `.sh` / `.ps1` / committed `AGENTS.md` and it has already drifted. We keep **one**
  source-of-truth block definition that the installer renders, so it cannot drift again.

### 3.5 Loop brain (namespaced under `loops/`)

Knowledge-base model carried over verbatim:

- Artifacts foldered **by kind** (`signal`, `doc` only — *earn* new kinds: a new kind needs
  its own status machine **and** queryable fields **and** distinct body shape).
- `domain:` is a frontmatter **field (a list), not a folder** — one concept, one home.
- Two-layer body: current-truth body + append-only `## Timeline`; two log surfaces only
  (per-artifact `## Timeline` + global `loops/LOG.md`).
- `loops/BOUNDARY.md` is the layer contract (product/market evidence → loop; proof,
  decisions, tooling-friction → harness).
- Namespacing under `loops/` is **also the brownfield safety**: the installer never collides
  with a target repo's own `docs/`.

### 3.6 Playbooks + optional `.claude` profile

Each loop skill becomes an agent-neutral `playbooks/*.md` procedure (referenced from the
LOOPS block). Portability from the source analysis:

| Source asset | v1 form |
|---|---|
| `dev-local-setup`, `new-loop`, `e2e-setup` | Straight playbooks (bodies already generic). |
| `pr`, `setup-codebase-harness` | Playbooks that describe sub-agent verification as an *optional* capability, not a requirement. |
| `ship-change.js` | Logic written up as `playbooks/ship-change.md` (described procedure). The runnable `.js` is kept **only** in the `.claude/` profile as a Claude-Code extra. |

The `.claude/skills/*/SKILL.md` wrappers are thin: frontmatter + a pointer to the playbook.
Non-Claude agents read the playbook directly; they treat an unrunnable skill as absent
(the harness's existing TOOL_REGISTRY philosophy).

### 3.7 CLI distribution + bootstrapping order

Vendor `crates/harness-cli` + the release workflow into the template repo, re-pointed to our
GitHub identity. **Order matters — `setup.sh`'s download cannot be tested until CI has
published assets under our repo:**

1. Vendor `crates/` + `.github/workflows/harness-cli-release.yml`; re-point all hardcoded
   `hoangnb24/repository-harness` URLs (installer `source-base-url`, `cli-base-url`, README
   one-liners) to the new repo.
2. Push + tag → CI builds `harness-cli-<platform>` + `.sha256` for macos-arm64/x64,
   linux-x64/arm64 (Windows deferred).
3. Re-point `scripts/harness-cli-release-tag` to the new tag.
4. Only then test `setup.sh` end-to-end.
5. During early dev, develop `setup.sh` against `HARNESS_CLI_BASE_URL` pointed at a local
   `cargo build` artifact.

**Repo-visibility nuance:** if the template repo is GitHub-private, the binary download needs
auth (token). Decide visibility before wiring the download (public template repo is simplest;
the CLI is MIT regardless).

### 3.8 `setup.sh` + `doctor.sh` (v1)

`setup.sh`:
1. Detect platform via `uname` → download CLI from our releases, verify SHA-256 (hard fail on
   mismatch), install to `scripts/bin/harness-cli` (chmod 755).
2. `harness-cli init` + `harness-cli migrate`.
3. Lay down vendor-managed files (whole-file copy, with `--merge`/`--override`/`--force`
   conflict handling inherited from the harness installer).
4. Marked-block-merge `AGENTS.md` (HARNESS + LOOPS blocks); with `--claude`, write/refresh
   `CLAUDE.md`.
5. Union-merge `.gitignore` (include `scripts/bin/harness-cli`, `harness.db*`).
6. Flags: `--merge` / `--override` / `--force` / `--dry-run` / `--claude` / `--yes`.

`doctor.sh` (the safety net a merge-installer needs):
- No unfilled placeholders remain.
- Required files + both marked blocks exist.
- CLI version ⇄ schema version ⇄ `harness-cli-release-tag` agree.
- `scripts/bin/harness-cli` is gitignored, not committed.
- Internal doc links resolve.
- `harness-cli query matrix` and `harness-cli audit` execute.
- Loop README schemas parse; domain/artifact frontmatter valid.
- No product-truth contradiction (e.g. AGENTS.md vs docs/product policy).

### 3.9 Content-strip — ship vs exclude

**Exclude (harness self-documentation, never ship to targets):** ADRs `0001–0007`,
`HARNESS_AUDIT.md`, `HARNESS_BACKLOG.md`, `HARNESS_COMPONENTS.md`, `HARNESS_MATURITY.md`,
`IMPROVEMENT_PROTOCOL.md`, `PHASE2–5.md`, the legacy `TEST_MATRIX.md`, and example stories
(`US-xxx`). **Exclude (loop marketing):** `assets/*.png`, AI-Builder-Club README sections.

**Ship empty (README/schema + templates only):** `docs/product/`, `docs/stories/`,
`docs/decisions/`, and all `loops/{signals,docs,domains}/`.

### 3.10 Licensing / NOTICE

Internal-only → direct fork+strip is acceptable. Add a `NOTICE` retaining the harness's MIT
copyright (Copyright (c) 2025 Hoang Nguyen) for harness-derived files. No public
redistribution of the loop-derived content.

## 4. Out of scope (v2+)

- `update` command + manifest (`.agent-kit/manifest.yml` with source SHAs / versions /
  checksums) for re-syncing vendor-managed files into an already-installed target.
- Windows `.ps1` installer parity, including `--claude`.
- Additional agent runtime profiles beyond Claude (Codex/Cursor) as first-class — they are
  served by the neutral playbooks via AGENTS.md for now.
- Re-authoring the loop layer clean-room for *public* distribution (only needed if the
  internal-only decision is later reversed).

## 5. Risks & open items

- **CLI bootstrapping circularity** (§3.7) — mitigated by the explicit order + local-build
  dev path.
- **Shim drift** — mitigated by single-sourcing the block text (§3.4).
- **Brownfield collisions** — mitigated by namespacing the brain under `loops/` and
  marked-block (not whole-file) merges of `AGENTS.md`.
- **Repo visibility vs binary download** (§3.7) — needs a one-line decision before wiring.

## 6. Build sequence (high level — detailed plan via writing-plans)

1. Scaffold the template repo skeleton + `NOTICE` + `.gitignore`.
2. Vendor + re-point `crates/` and the release workflow; publish a first CLI release.
3. Strip & lay down the harness `docs/` system-of-record (per §3.9) + schema.
4. Fork & namespace the loop brain under `loops/` (re-prefix all bare paths) + `BOUNDARY.md`.
5. Author `playbooks/*` + the thin `.claude/` profile.
6. Write `setup.sh` (two-block merge, single-sourced shim) + `doctor.sh`.
7. Validate against fixtures: empty repo, brownfield repo, repo with an existing
   `AGENTS.md`/`CLAUDE.md`.

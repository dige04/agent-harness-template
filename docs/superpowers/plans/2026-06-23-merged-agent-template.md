# Merged Agent-Neutral Harness + Loop Template — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one internally-owned, agent-neutral (AGENTS.md-first) template that installs the harness (proof) + loop (memory) layers into any repo via `setup.sh`.

**Architecture:** Fork+strip both source systems into a single repo we own. The harness `docs/` system-of-record + Rust CLI form the "hands/receipts" layer; a markdown KB under `loops/` forms the "brain/memory" layer; `loops/BOUNDARY.md` is the contract. `setup.sh` (one installer, two run-modes) lays down vendor-managed files, downloads the per-platform CLI from our own GitHub release, inits the SQLite durable layer, and idempotently merges two marked blocks (`HARNESS`, `LOOPS`) into the target's `AGENTS.md`. `doctor.sh` validates the result.

**Tech Stack:** Bash (installer/doctor + tests, dependency-free), Rust (vendored `harness-cli`, `rusqlite` bundled SQLite), GitHub Actions (release CI), Markdown (docs/playbooks/KB).

**Spec:** `docs/superpowers/specs/2026-06-23-merged-agent-template-design.md` (read it first).

**Source repos (read-only references to fork from):**
- Harness: `/Users/hieudinh/Documents/experiments/repository-harness` (MIT, CLI `0.1.10`)
- Loop: `/Users/hieudinh/Documents/experiments/loop-engineer-template` (unlicensed; internal-use fork OK)

## Global Constraints

- **AGENTS.md is the primary contract; CLAUDE.md is secondary** (thin `@AGENTS.md` bridge, only with `--claude`). Claude-specifics live only under `.claude/`.
- **Agent-neutral:** no task may make a Claude-only mechanism (Skill tool, slash commands, sub-agent spawning, Agent SDK) a *hard requirement*. Such capabilities are optional.
- **CLI version pin:** `0.1.10`, schema version `5` (migrations `001`–`005`). These must agree (`harness-cli --version` ⇄ `scripts/harness-cli-release-tag` ⇄ highest `scripts/schema/NNN`).
- **Template repo is PUBLIC** → CLI binary download is unauthenticated `curl`. No token handling.
- **Never commit:** `scripts/bin/harness-cli`, `harness.db`, `harness.db-wal`, `harness.db-shm` (gitignored).
- **Never ship to targets:** `crates/`, `.github/workflows/harness-cli-release.yml`, the source-doc-strip exclusion list (Task 2.1).
- **Single-source the block text:** the HARNESS and LOOPS block bodies are defined in exactly one file (`scripts/lib/blocks.sh`); the installer renders from it. No copies in `.ps1` or committed `AGENTS.md`.
- **Licensing:** keep `NOTICE` retaining harness MIT copyright (Copyright (c) 2025 Hoang Nguyen).
- **Repo identity placeholder:** `OWNER/REPO` = the new public GitHub repo (decide exact slug in Task 1.3; use the chosen value verbatim everywhere thereafter).
- **Commit cadence:** one commit per completed task (frequent commits).

---

## Phase 0 — Repo skeleton

### Task 0: Skeleton, .gitignore, NOTICE, README

**Files:**
- Create: `.gitignore`, `NOTICE`, `README.md`, `scripts/lib/.gitkeep`, `tests/.gitkeep`
- (Repo already inited at `/Users/hieudinh/Documents/experiments/agent-harness-template`; specs/plans already committed.)

**Interfaces:**
- Produces: the directory skeleton every later task writes into.

- [ ] **Step 1: Write `.gitignore`**

```
# Harness durable layer — local-only; schema is version-controlled
harness.db
harness.db-*
*.db
# Downloaded per-platform CLI binary — never committed
scripts/bin/harness-cli
scripts/bin/harness-cli.exe
# Env / OS
.env*
.DS_Store
.claude/settings.local.json
node_modules/
```

- [ ] **Step 2: Write `NOTICE`**

```
This template includes software derived from repository-harness
(https://github.com/hoangnb24/repository-harness), licensed under the MIT License,
Copyright (c) 2025 Hoang Nguyen. The MIT license text is retained in LICENSE-harness.
```

- [ ] **Step 3: Copy the harness MIT license verbatim**

Run: `cp /Users/hieudinh/Documents/experiments/repository-harness/LICENSE ./LICENSE-harness`
Expected: file present, contains "MIT License" and "Hoang Nguyen".

- [ ] **Step 4: Write `README.md`** (one paragraph: what this is, "run `scripts/setup.sh` in a target repo", link to the spec). Keep ≤30 lines, no marketing.

- [ ] **Step 5: Create empty dirs** `scripts/lib/` and `tests/` with `.gitkeep` files.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "chore: repo skeleton, gitignore, NOTICE, harness license"
```

---

## Phase 1 — CLI: vendor, re-point, publish

> **Prerequisite for Task 1.3:** a GitHub account with `gh` authenticated and ability to create a public repo. Tasks 1.1–1.2 and 1.4 are local; 1.3 requires network + GitHub Actions.

### Task 1.1: Vendor the Rust CLI source

**Files:**
- Create: `crates/harness-cli/**` (copied), `Cargo.toml`, `Cargo.lock`
- Modify: `crates/harness-cli/Cargo.toml` (package metadata)

**Interfaces:**
- Produces: a buildable `harness-cli` binary; `harness-cli --version` → `0.1.10`.

- [ ] **Step 1: Copy the crate + workspace manifests**

```bash
cp -R /Users/hieudinh/Documents/experiments/repository-harness/crates ./crates
cp /Users/hieudinh/Documents/experiments/repository-harness/Cargo.toml ./Cargo.toml
cp /Users/hieudinh/Documents/experiments/repository-harness/Cargo.lock ./Cargo.lock
```

- [ ] **Step 2: Build to verify the vendored source compiles**

Run: `cargo build --release`
Expected: builds; `./target/release/harness-cli --version` prints `harness-cli 0.1.10`.

- [ ] **Step 3: Update package metadata** in `crates/harness-cli/Cargo.toml` — keep `version = "0.1.10"` and `license = "MIT"`; update `repository`/`homepage` (if present) to `https://github.com/OWNER/REPO`. Do not change the version number.

- [ ] **Step 4: Re-run build to confirm metadata edit didn't break anything**

Run: `cargo build --release` → Expected: success, version still `0.1.10`.

- [ ] **Step 5: Commit**

```bash
git add crates Cargo.toml Cargo.lock && git commit -m "feat(cli): vendor harness-cli 0.1.10 source"
```

### Task 1.2: Vendor + re-point the release workflow

**Files:**
- Create: `.github/workflows/harness-cli-release.yml` (copied + re-pointed)
- Reference: `/Users/hieudinh/Documents/experiments/repository-harness/scripts/build-harness-cli-release.sh`

**Interfaces:**
- Produces: a tag-triggered workflow that builds `harness-cli-<platform>` + `.sha256` for macos-arm64, macos-x64, linux-x64, linux-arm64 and attaches them to a GitHub release.

- [ ] **Step 1: Copy the workflow + build script**

```bash
cp /Users/hieudinh/Documents/experiments/repository-harness/.github/workflows/harness-cli-release.yml ./.github/workflows/
cp /Users/hieudinh/Documents/experiments/repository-harness/scripts/build-harness-cli-release.sh ./scripts/
```

- [ ] **Step 2: Find every hardcoded upstream identity**

Run: `grep -rn "hoangnb24/repository-harness" .github scripts crates`
Expected: a list of matches (workflow, build script). Record them.

- [ ] **Step 3: Re-point all matches to `OWNER/REPO`**

Run (after setting `OWNER/REPO`): `grep -rl "hoangnb24/repository-harness" .github scripts crates | xargs sed -i '' 's#hoangnb24/repository-harness#OWNER/REPO#g'` (note: `sed -i ''` is macOS syntax).
Then re-run the grep from Step 2 → Expected: **no matches**.

- [ ] **Step 4: Confirm the platform matrix** includes macos-arm64, macos-x64, linux-x64, linux-arm64 (Windows deferred per spec §4). Edit the matrix if any are missing.

- [ ] **Step 5: Commit**

```bash
git add .github scripts/build-harness-cli-release.sh && git commit -m "ci(cli): vendor + re-point release workflow to OWNER/REPO"
```

### Task 1.3: Publish the first CLI release

**Files:** none (network operation).

- [ ] **Step 1: Create the public GitHub repo + push**

```bash
gh repo create OWNER/REPO --public --source=. --remote=origin --push
```
Expected: repo created, `main` pushed. Record the final `OWNER/REPO` slug and use it verbatim from here on.

- [ ] **Step 2: Tag the release**

```bash
git tag harness-cli-v0.1.10 && git push origin harness-cli-v0.1.10
```

- [ ] **Step 3: Wait for CI, then verify assets exist**

Run: `gh release view harness-cli-v0.1.10 --json assets --jq '.assets[].name'`
Expected: includes `harness-cli-macos-arm64`, `harness-cli-macos-x64`, `harness-cli-linux-x64`, `harness-cli-linux-arm64`, and a `.sha256` for each.

- [ ] **Step 4: Download one asset + verify its checksum manually**

```bash
gh release download harness-cli-v0.1.10 -p 'harness-cli-macos-arm64*' -D /tmp/cli-check
cd /tmp/cli-check && shasum -a 256 -c harness-cli-macos-arm64.sha256
```
Expected: `harness-cli-macos-arm64: OK`.

### Task 1.4: Pin the release tag

**Files:**
- Create: `scripts/harness-cli-release-tag`

- [ ] **Step 1: Write the pin file** containing exactly `harness-cli-v0.1.10` (single line, no trailing content beyond a newline).

- [ ] **Step 2: Verify**

Run: `cat scripts/harness-cli-release-tag` → Expected: `harness-cli-v0.1.10`.

- [ ] **Step 3: Commit**

```bash
git add scripts/harness-cli-release-tag && git commit -m "chore(cli): pin release tag harness-cli-v0.1.10"
```

---

## Phase 2 — Harness docs layer (strip + lay down)

### Task 2.1: Lay down the harness system-of-record (stripped)

**Files (Create, copied from `repository-harness/docs/`):**
- `docs/HARNESS.md`, `docs/FEATURE_INTAKE.md`, `docs/CONTEXT_RULES.md`, `docs/TRACE_SPEC.md`, `docs/GLOSSARY.md`, `docs/TOOL_REGISTRY.md`, `docs/ARCHITECTURE.md`
- `docs/templates/decision.md`, `docs/templates/story.md`, `docs/templates/spec-intake.md`, `docs/templates/validation-report.md`, `docs/templates/high-risk-story/**`
- `docs/product/README.md`, `docs/stories/README.md`, `docs/decisions/README.md` (READMEs only — empty layers)
- `scripts/schema/001-init.sql` … `005-tool-extensions.sql`
- `scripts/README.md` (the installed-payload note)

**EXCLUDE (must NOT exist in this repo's `docs/`):** `decisions/0001`–`0007`*.md, `HARNESS_AUDIT.md`, `HARNESS_BACKLOG.md`, `HARNESS_COMPONENTS.md`, `HARNESS_MATURITY.md`, `IMPROVEMENT_PROTOCOL.md`, `TEST_MATRIX.md`, `PHASE2.md`–`PHASE5.md`, `docs/stories/epics/**`, `docs/stories/US-*.md`, `docs/demo/**`, `docs/superpowers/**` (those source files are example/self-doc content).

- [ ] **Step 1: Copy the ship-list docs explicitly** (one `cp` per file/dir above, from `/Users/hieudinh/Documents/experiments/repository-harness/docs/...`). Use an explicit allow-list — do NOT `cp -R docs/`.

- [ ] **Step 2: Copy the schema**

```bash
cp /Users/hieudinh/Documents/experiments/repository-harness/scripts/schema/*.sql ./scripts/schema/
cp /Users/hieudinh/Documents/experiments/repository-harness/scripts/README.md ./scripts/README.md
```

- [ ] **Step 3: Empty the project-owned layers** — for `docs/product/`, `docs/stories/`, `docs/decisions/`, keep ONLY `README.md`. Remove any copied example content.

- [ ] **Step 4: Assert the exclusion list is absent**

Run: `for f in HARNESS_AUDIT.md HARNESS_BACKLOG.md HARNESS_COMPONENTS.md HARNESS_MATURITY.md IMPROVEMENT_PROTOCOL.md TEST_MATRIX.md PHASE2.md; do test ! -e "docs/$f" || echo "LEAK: $f"; done; ls docs/decisions/`
Expected: no `LEAK:` lines; `docs/decisions/` shows only `README.md`.

- [ ] **Step 5: Assert schema completeness**

Run: `ls scripts/schema/ | sort` → Expected: `001-init.sql` through `005-tool-extensions.sql` (5 files).

- [ ] **Step 6: Commit**

```bash
git add docs scripts/schema scripts/README.md && git commit -m "feat(harness): lay down stripped docs system-of-record + schema v5"
```

---

## Phase 3 — Loop brain (fork + namespace under `loops/`)

### Task 3.1: Fork + namespace the KB scaffold

**Files (Create under `loops/`, forked from `loop-engineer-template/`):**
- `loops/ARCHITECTURE.md` (from root `ARCHITECTURE.md`)
- `loops/LOG.md` (header only — strip any example entries to a clean template)
- `loops/signals/README.md`, `loops/docs/README.md`, `loops/domains/README.md` (the kind/domain schemas)

**Do NOT copy:** root `README.md`, `assets/*.png`, `CLAUDE.md` (loop side), or any AI-Builder-Club marketing prose.

- [ ] **Step 1: Copy the scaffold files** into `loops/` (explicit per-file `cp`).

- [ ] **Step 2: Re-prefix all bare root-relative paths** in the copied files to the `loops/` namespace. The source uses bare `ARCHITECTURE.md`, `signals/`, `docs/`, `domains/`, `LOG.md`. Rewrite to `loops/ARCHITECTURE.md`, `loops/signals/`, `loops/docs/`, `loops/domains/`, `loops/LOG.md`.

- [ ] **Step 3: Assert no bare paths and no marketing remain**

Run: `grep -rnE '(^|[^/])(ARCHITECTURE\.md|LOG\.md)|(^|[^a-z])(signals|domains)/' loops/ | grep -v 'loops/'` → Expected: no output (every reference is namespaced).
Run: `grep -rniE 'ai.?builder|jason.?zhou|video-thumbnail' loops/` → Expected: no output.

- [ ] **Step 4: Assert LOG.md is a clean template** (no real dated entries) — Run: `grep -c '^## 20' loops/LOG.md` → Expected: `0`.

- [ ] **Step 5: Commit**

```bash
git add loops && git commit -m "feat(loops): fork + namespace KB scaffold under loops/"
```

### Task 3.2: Author `loops/BOUNDARY.md`

**Files:**
- Create: `loops/BOUNDARY.md`

**Interfaces:**
- Produces: the one-home-per-concept contract referenced by the LOOPS block (Task 5.1).

- [ ] **Step 1: Write `loops/BOUNDARY.md`** — generalize the francais.vn version (concept seen in this session). It MUST contain: the two-layer table (loop = brain/memory; harness = hands/receipts), the "one home per concept" mapping table (product/market evidence → `loops/signals/`; durable analysis → `loops/docs/`; decisions → `docs/decisions/` + `harness-cli decision`; shipping code → harness story; proof → harness `query matrix`; tooling friction → harness backlog; human activity feed → `loops/LOG.md`), and a "which layer?" quick test. Use generic language (no "francais.vn").

- [ ] **Step 2: Assert it has no project-specific names**

Run: `grep -niE 'francais|learner|vietnamese' loops/BOUNDARY.md` → Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add loops/BOUNDARY.md && git commit -m "feat(loops): add generic BOUNDARY.md layer contract"
```

---

## Phase 4 — Playbooks + optional `.claude` profile

### Task 4.1: Author the agent-neutral playbooks

**Files (Create):**
- `playbooks/new-loop.md`, `playbooks/dev-local-setup.md`, `playbooks/e2e-setup.md`, `playbooks/pr.md`, `playbooks/ship-change.md`

**Source to adapt from** (fork the procedure prose; internal-use OK): `loop-engineer-template/.claude/skills/<name>/SKILL.md`, and `ship-change.js` for the ship-change procedure.

**Interfaces:**
- Produces: procedure docs referenced from the LOOPS block. Each must read as "any agent can follow this."

- [ ] **Step 1: Write each playbook** as: purpose, when-to-use, numbered procedure, success criteria. Convert Claude-only mechanisms to optional: "spawn a fresh verifier sub-agent" → "have an *independent* check the running feature (a sub-agent if your runtime supports it, otherwise a separate review pass)". `dev-local-setup.md` retains the generic `dev-local.template.sh` reference.

- [ ] **Step 2: Copy the one genuinely portable asset**

```bash
cp /Users/hieudinh/Documents/experiments/loop-engineer-template/.claude/skills/dev-local-setup/assets/dev-local.template.sh ./playbooks/assets/dev-local.template.sh
```

- [ ] **Step 3: Assert no hard Claude requirement**

Run: `grep -rniE '\bSkill tool\b|/[a-z-]+ slash|claude code is required|must use claude' playbooks/` → Expected: no output (mentions are allowed only as optional capabilities; this grep targets *requirement* phrasing — eyeball any hits).

- [ ] **Step 4: Commit**

```bash
git add playbooks && git commit -m "feat(playbooks): agent-neutral procedure docs (source of truth)"
```

### Task 4.2: Thin `.claude` profile

**Files (Create):**
- `.claude/skills/{new-loop,dev-local-setup,e2e-setup,pr,setup-codebase-harness}/SKILL.md`
- `.claude/workflows/ship-change.js` (copied verbatim — Claude-only extra)

**Interfaces:**
- Consumes: `playbooks/*.md`.
- Produces: optional Claude-Code ergonomics; each SKILL.md is a thin wrapper.

- [ ] **Step 1: Write each `SKILL.md`** with valid frontmatter (`name`, `description`, `user_invocable: true` for pr/setup-codebase-harness) and a body that points at the corresponding `playbooks/<name>.md` ("This skill executes the procedure in `playbooks/<name>.md`."). Keep bodies ≤25 lines.

- [ ] **Step 2: Copy the workflow**

```bash
cp /Users/hieudinh/Documents/experiments/loop-engineer-template/.claude/workflows/ship-change.js ./.claude/workflows/ship-change.js
```

- [ ] **Step 3: Assert frontmatter validity** — Run: `for f in .claude/skills/*/SKILL.md; do head -1 "$f" | grep -q '^---' || echo "BAD FRONTMATTER: $f"; done` → Expected: no `BAD` lines.

- [ ] **Step 4: Commit**

```bash
git add .claude && git commit -m "feat(profile): thin .claude skill wrappers + ship-change workflow"
```

---

## Phase 5 — `setup.sh` installer (TDD against fixtures)

> **Test harness:** dependency-free bash. Create `tests/helpers.sh` with `assert_eq`, `assert_contains`, `assert_file`, `mk_fixture` (makes a temp dir, returns its path). Each test script sources it, runs, prints `PASS`/`FAIL`, exits non-zero on any failure. Run a test with `bash tests/<name>.sh`.

### Task 5.0: Test helpers

**Files:** Create `tests/helpers.sh`

- [ ] **Step 1: Write `tests/helpers.sh`**

```bash
#!/usr/bin/env bash
set -uo pipefail
FAILED=0
assert_eq()      { [ "$1" = "$2" ] && echo "  ok: $3" || { echo "  FAIL: $3 (got '$1' want '$2')"; FAILED=1; }; }
assert_contains(){ grep -q "$2" "$1" && echo "  ok: $3" || { echo "  FAIL: $3 ('$2' not in $1)"; FAILED=1; }; }
assert_absent()  { grep -q "$2" "$1" && { echo "  FAIL: $3 ('$2' unexpectedly in $1)"; FAILED=1; } || echo "  ok: $3"; }
assert_file()    { [ -e "$1" ] && echo "  ok: exists $1" || { echo "  FAIL: missing $1"; FAILED=1; }; }
mk_fixture()     { mktemp -d "${TMPDIR:-/tmp}/aht-fixture.XXXXXX"; }
finish()         { [ "$FAILED" -eq 0 ] && echo "ALL PASS" || { echo "TESTS FAILED"; exit 1; }; }
```

- [ ] **Step 2: Sanity-run** — Run: `bash -c 'source tests/helpers.sh; assert_eq a a "self"; finish'` → Expected: `ok: self` then `ALL PASS`.

- [ ] **Step 3: Commit** — `git add tests/helpers.sh && git commit -m "test: dependency-free bash assert helpers"`

### Task 5.1: Single-sourced block definitions

**Files:** Create `scripts/lib/blocks.sh`, `tests/blocks.test.sh`

**Interfaces:**
- Produces: `render_harness_block()` and `render_loops_block()` — each echoes its block body *including* the `<!-- HARNESS:BEGIN -->…<!-- HARNESS:END -->` (resp. `LOOPS`) markers. Consumed by the merge function (Task 5.2) and doctor (Phase 6).

- [ ] **Step 1: Write the failing test** `tests/blocks.test.sh`

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
source "$(dirname "$0")/../scripts/lib/blocks.sh"
out=$(render_harness_block)
echo "$out" | grep -q '<!-- HARNESS:BEGIN -->' && echo "  ok: harness begin" || { echo "  FAIL harness begin"; FAILED=1; }
echo "$out" | grep -q '<!-- HARNESS:END -->'   && echo "  ok: harness end"   || { echo "  FAIL harness end"; FAILED=1; }
echo "$out" | grep -q 'harness-cli query matrix' && echo "  ok: cli ref" || { echo "  FAIL cli ref"; FAILED=1; }
out2=$(render_loops_block)
echo "$out2" | grep -q '<!-- LOOPS:BEGIN -->' && echo "  ok: loops begin" || { echo "  FAIL loops begin"; FAILED=1; }
echo "$out2" | grep -q 'loops/BOUNDARY.md'    && echo "  ok: boundary ref" || { echo "  FAIL boundary ref"; FAILED=1; }
finish
```

- [ ] **Step 2: Run to verify it fails** — Run: `bash tests/blocks.test.sh` → Expected: FAIL (`blocks.sh` not found / functions undefined).

- [ ] **Step 3: Write `scripts/lib/blocks.sh`**

```bash
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
```

- [ ] **Step 4: Run to verify it passes** — Run: `bash tests/blocks.test.sh` → Expected: all `ok`, `ALL PASS`.

- [ ] **Step 5: Commit** — `git add scripts/lib/blocks.sh tests/blocks.test.sh && git commit -m "feat(setup): single-sourced HARNESS+LOOPS block definitions"`

### Task 5.2: Two-region marked-block merge

**Files:** Create `scripts/lib/merge_blocks.sh`, `tests/merge_blocks.test.sh`

**Interfaces:**
- Consumes: `render_harness_block`, `render_loops_block` (Task 5.1).
- Produces: `upsert_block <file> <BEGIN_MARKER> <END_MARKER> <rendered_block>` — if the file lacks the marker pair, append the block; if present, replace the region in place. Idempotent. Preserves all other content.

- [ ] **Step 1: Write the failing test** `tests/merge_blocks.test.sh`

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
source "$(dirname "$0")/../scripts/lib/blocks.sh"
source "$(dirname "$0")/../scripts/lib/merge_blocks.sh"
d=$(mk_fixture)
# Case A: no file -> create with project header + both blocks
f="$d/AGENTS.md"; printf '# Agent Instructions\n\nProject prose here.\n' > "$f"
upsert_block "$f" '<!-- HARNESS:BEGIN -->' '<!-- HARNESS:END -->' "$(render_harness_block)"
upsert_block "$f" '<!-- LOOPS:BEGIN -->'   '<!-- LOOPS:END -->'   "$(render_loops_block)"
assert_contains "$f" 'Project prose here.' "A: prose preserved"
assert_contains "$f" 'harness-cli query matrix' "A: harness block present"
assert_contains "$f" 'loops/BOUNDARY.md' "A: loops block present"
# Case B: idempotent — running again must not duplicate
upsert_block "$f" '<!-- HARNESS:BEGIN -->' '<!-- HARNESS:END -->' "$(render_harness_block)"
assert_eq "$(grep -c '<!-- HARNESS:BEGIN -->' "$f")" "1" "B: no duplicate harness block"
# Case C: stale block replaced in place, prose + other block survive
perl -0pi -e 's/Operate the durable layer.*/STALE LINE/s if /HARNESS:BEGIN/../HARNESS:END/' "$f" 2>/dev/null || true
upsert_block "$f" '<!-- HARNESS:BEGIN -->' '<!-- HARNESS:END -->' "$(render_harness_block)"
assert_contains "$f" 'harness-cli query matrix' "C: harness refreshed"
assert_contains "$f" 'loops/BOUNDARY.md' "C: loops block survived"
assert_contains "$f" 'Project prose here.' "C: prose survived"
finish
```

- [ ] **Step 2: Run to verify it fails** — Run: `bash tests/merge_blocks.test.sh` → Expected: FAIL (`merge_blocks.sh` not found).

- [ ] **Step 3: Write `scripts/lib/merge_blocks.sh`**

```bash
#!/usr/bin/env bash
# upsert_block FILE BEGIN END BLOCK — append BLOCK if BEGIN/END absent, else replace region in place.
upsert_block() {
  local file="$1" begin="$2" end="$3" block="$4" tmp
  tmp="$(mktemp)"
  if grep -qF "$begin" "$file" 2>/dev/null && grep -qF "$end" "$file"; then
    awk -v b="$begin" -v e="$end" -v repl="$block" '
      index($0,b){print repl; skip=1; next}
      skip && index($0,e){skip=0; next}
      skip{next}
      {print}
    ' "$file" > "$tmp"
  else
    { cat "$file" 2>/dev/null; printf '\n%s\n' "$block"; } > "$tmp"
  fi
  mv "$tmp" "$file"
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `bash tests/merge_blocks.test.sh` → Expected: all `ok`, `ALL PASS`.

- [ ] **Step 5: Commit** — `git add scripts/lib/merge_blocks.sh tests/merge_blocks.test.sh && git commit -m "feat(setup): idempotent two-region marked-block merge"`

### Task 5.3: Platform detection + binary download + checksum

**Files:** Create `scripts/lib/cli_download.sh`, `tests/cli_download.test.sh`

**Interfaces:**
- Produces: `detect_platform()` → echoes `macos-arm64|macos-x64|linux-x64|linux-arm64`; `download_cli <dest_dir>` → downloads the pinned binary + `.sha256` from `${HARNESS_CLI_BASE_URL:-https://github.com/OWNER/REPO/releases/download/<tag>}`, verifies the checksum (hard-fail on mismatch), installs to `<dest_dir>/harness-cli` (chmod 755). Tag read from `scripts/harness-cli-release-tag`.

- [ ] **Step 1: Write the failing test** `tests/cli_download.test.sh` (uses a local fake "release" dir via `HARNESS_CLI_BASE_URL=file://...` so it needs no network)

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
source "$(dirname "$0")/../scripts/lib/cli_download.sh"
p=$(detect_platform); echo "$p" | grep -qE '^(macos|linux)-(arm64|x64)$' && echo "  ok: platform $p" || { echo "  FAIL platform"; FAILED=1; }
# Build a fake release dir
rel=$(mk_fixture); plat=$(detect_platform)
printf 'FAKEBIN\n' > "$rel/harness-cli-$plat"
( cd "$rel" && shasum -a 256 "harness-cli-$plat" > "harness-cli-$plat.sha256" )
dest=$(mk_fixture)
HARNESS_CLI_BASE_URL="file://$rel" download_cli "$dest"
assert_file "$dest/harness-cli" "binary installed"
[ -x "$dest/harness-cli" ] && echo "  ok: executable" || { echo "  FAIL not executable"; FAILED=1; }
# Corrupt checksum -> must fail
bad=$(mk_fixture); printf 'OTHER\n' > "$bad/harness-cli-$plat"; printf 'deadbeef  harness-cli-'"$plat"'\n' > "$bad/harness-cli-$plat.sha256"
dest2=$(mk_fixture)
if HARNESS_CLI_BASE_URL="file://$bad" download_cli "$dest2" 2>/dev/null; then echo "  FAIL: bad checksum accepted"; FAILED=1; else echo "  ok: bad checksum rejected"; fi
finish
```

- [ ] **Step 2: Run to verify it fails** — Run: `bash tests/cli_download.test.sh` → Expected: FAIL (`cli_download.sh` not found).

- [ ] **Step 3: Write `scripts/lib/cli_download.sh`** (support `file://` and `https://` via curl; verify with `shasum -a 256 -c`)

```bash
#!/usr/bin/env bash
detect_platform() {
  local os arch; os="$(uname -s)"; arch="$(uname -m)"
  case "$os" in Darwin) os=macos;; Linux) os=linux;; *) echo "unsupported os: $os" >&2; return 1;; esac
  case "$arch" in arm64|aarch64) arch=arm64;; x86_64|amd64) arch=x64;; *) echo "unsupported arch: $arch" >&2; return 1;; esac
  echo "${os}-${arch}"
}
_fetch() { # _fetch URL DEST
  case "$1" in file://*) cp "${1#file://}" "$2";; *) curl -fsSL "$1" -o "$2";; esac
}
download_cli() {
  local dest="$1" plat tag base bin sum dir
  plat="$(detect_platform)" || return 1
  tag="$(cat "$(dirname "${BASH_SOURCE[0]}")/../harness-cli-release-tag")"
  base="${HARNESS_CLI_BASE_URL:-https://github.com/OWNER/REPO/releases/download/$tag}"
  dir="$(mktemp -d)"; bin="harness-cli-$plat"; sum="$bin.sha256"
  _fetch "$base/$bin" "$dir/$bin" || { echo "download failed: $base/$bin" >&2; return 1; }
  _fetch "$base/$sum" "$dir/$sum" || { echo "checksum download failed" >&2; return 1; }
  ( cd "$dir" && shasum -a 256 -c "$sum" ) || { echo "CHECKSUM MISMATCH for $bin" >&2; return 1; }
  mkdir -p "$dest"; mv "$dir/$bin" "$dest/harness-cli"; chmod 755 "$dest/harness-cli"
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `bash tests/cli_download.test.sh` → Expected: all `ok`, `ALL PASS`.

- [ ] **Step 5: Commit** — `git add scripts/lib/cli_download.sh tests/cli_download.test.sh && git commit -m "feat(setup): platform detect + checksum-verified CLI download"`

### Task 5.4: File lay-down + .gitignore union + DB init

**Files:** Create `scripts/lib/layout.sh`, `tests/layout.test.sh`

**Interfaces:**
- Consumes: a built/downloaded `harness-cli` (for `init_db`).
- Produces: `lay_down_files <src_root> <target> <mode>` (mode = `merge|override`; copies the vendor-managed manifest; `merge` skips existing, `override` backs up to `.harness-backup/<ts>` then replaces); `merge_gitignore <src> <target>` (append missing lines only); `init_db <target>` (runs `harness-cli init` + `migrate` with `HARNESS_REPO_ROOT=<target>`).

- [ ] **Step 1: Write the failing test** `tests/layout.test.sh` covering: merge skips an existing file; gitignore union adds missing lines without duplicating present ones.

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
source "$(dirname "$0")/../scripts/lib/layout.sh"
src=$(mk_fixture); tgt=$(mk_fixture)
mkdir -p "$src/docs"; printf 'NEW\n' > "$src/docs/HARNESS.md"
mkdir -p "$tgt/docs"; printf 'EXISTING\n' > "$tgt/docs/HARNESS.md"
VENDOR_MANIFEST=("docs/HARNESS.md")
lay_down_files "$src" "$tgt" merge
assert_contains "$tgt/docs/HARNESS.md" 'EXISTING' "merge keeps existing"
printf '.env*\n*.db\n' > "$src/.gitignore"; printf '*.db\n' > "$tgt/.gitignore"
merge_gitignore "$src/.gitignore" "$tgt/.gitignore"
assert_eq "$(grep -c '\*.db' "$tgt/.gitignore")" "1" "gitignore no dup"
assert_contains "$tgt/.gitignore" '.env\*' "gitignore added missing"
finish
```

- [ ] **Step 2: Run to verify it fails** — Run: `bash tests/layout.test.sh` → Expected: FAIL.

- [ ] **Step 3: Write `scripts/lib/layout.sh`** — implement `lay_down_files` iterating `${VENDOR_MANIFEST[@]}` (a `merge` mode `[ -e target ] && continue`; `override` mode backs up then copies), `merge_gitignore` (for each src line, `grep -qxF` target before appending), `init_db` (`HARNESS_REPO_ROOT="$1" "$1/scripts/bin/harness-cli" init && ... migrate`). Define the real `VENDOR_MANIFEST` array of every vendor-managed path from spec §3.3.

- [ ] **Step 4: Run to verify it passes** — Run: `bash tests/layout.test.sh` → Expected: `ALL PASS`.

- [ ] **Step 5: Commit** — `git add scripts/lib/layout.sh tests/layout.test.sh && git commit -m "feat(setup): file lay-down, gitignore union, db init"`

### Task 5.5: Assemble `setup.sh` + flags

**Files:** Create `scripts/setup.sh`; Create `tests/setup_integration.test.sh`

**Interfaces:**
- Consumes: all `scripts/lib/*.sh`.
- Produces: the installer entrypoint. Flags: `--merge|--override|--force|--dry-run|--claude|--yes`, `--target <dir>` (default `.`). Detects local vs remote source root.

- [ ] **Step 1: Write the failing integration test** `tests/setup_integration.test.sh` — create an empty fixture target, run `scripts/setup.sh --target "$tgt" --merge --yes` with `HARNESS_CLI_BASE_URL=file://<local-build-release>` (build the binary first into a fake release dir), assert: `docs/HARNESS.md`, `loops/BOUNDARY.md`, `playbooks/pr.md` exist; `AGENTS.md` contains both blocks; `scripts/bin/harness-cli` exists and is gitignored; `harness.db` created.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`setup.sh` not found).

- [ ] **Step 3: Write `scripts/setup.sh`** — parse flags; resolve `SRC_ROOT` (local: dir containing this script's `..`; remote: curl base); source `lib/*.sh`; `--dry-run` prints the plan and exits; else: `download_cli "$TARGET/scripts/bin"` → `lay_down_files SRC_ROOT TARGET mode` → `merge_gitignore` → `init_db` → `upsert_block` HARNESS + LOOPS into `$TARGET/AGENTS.md` (creating header `# Agent Instructions` if absent) → if `--claude`, write `$TARGET/CLAUDE.md` containing `@AGENTS.md` (upsert a CLAUDE block). Echo a summary.

- [ ] **Step 4: Run to verify it passes** — Run: `bash tests/setup_integration.test.sh` → Expected: `ALL PASS`.

- [ ] **Step 5: Commit** — `git add scripts/setup.sh tests/setup_integration.test.sh && git commit -m "feat(setup): assemble installer with flags + integration test"`

---

## Phase 6 — `doctor.sh` (TDD)

### Task 6: Health checks

**Files:** Create `scripts/doctor.sh`, `tests/doctor.test.sh`

**Interfaces:**
- Produces: `doctor.sh [--target <dir>]` exits 0 if all checks pass, non-zero with a report otherwise. Checks (each a function): no unfilled `{{PLACEHOLDER}}`; both marked blocks present in `AGENTS.md`; CLI `--version` ⇄ highest `scripts/schema/NNN` ⇄ `harness-cli-release-tag` agree on `0.1.10`/`5`/`v0.1.10`; `scripts/bin/harness-cli` is gitignored (`git check-ignore`); internal markdown links resolve; `harness-cli query matrix` and `audit` exit 0; `loops/*/README.md` exist.

- [ ] **Step 1: Write the failing test** `tests/doctor.test.sh` — run setup into a fixture (reuse Task 5.5 setup), then assert `scripts/doctor.sh --target "$tgt"` exits 0; then break one thing (e.g. inject `{{TODO}}` into `AGENTS.md`) and assert it exits non-zero and reports the placeholder.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`doctor.sh` not found).

- [ ] **Step 3: Write `scripts/doctor.sh`** — each check echoes `ok:`/`FAIL:` and bumps a failure counter; final exit code = (failures>0). Implement the version⇄schema⇄tag agreement by parsing `harness-cli --version`, `ls scripts/schema | tail -1`, and `cat scripts/harness-cli-release-tag`. Placeholder check: `grep -rn '{{[A-Z_]*}}' AGENTS.md docs loops playbooks`.

- [ ] **Step 4: Run to verify it passes** — Run: `bash tests/doctor.test.sh` → Expected: `ALL PASS`.

- [ ] **Step 5: Commit** — `git add scripts/doctor.sh tests/doctor.test.sh && git commit -m "feat(doctor): health checks + tests"`

---

## Phase 7 — End-to-end fixture validation

### Task 7: Three install scenarios green

**Files:** Create `tests/e2e.test.sh`

**Interfaces:**
- Consumes: `setup.sh`, `doctor.sh`. Uses `HARNESS_CLI_BASE_URL=file://<local-build-release>` (build binary once at top).

- [ ] **Step 1: Write `tests/e2e.test.sh`** with three cases, each ending in `doctor.sh` exit 0:
  - **Empty repo:** `git init` fixture → `setup.sh --merge --claude --yes` → doctor passes; assert `CLAUDE.md` contains `@AGENTS.md`.
  - **Brownfield:** fixture with a pre-existing `docs/CONTRIBUTING.md` and an `AGENTS.md` containing `# Agent Instructions\n\nCUSTOM PROSE` → `setup.sh --merge --yes` → assert `CUSTOM PROSE` survived, both blocks present, and `docs/CONTRIBUTING.md` untouched (no `docs/` clobber).
  - **Existing CLAUDE.md:** fixture with a `CLAUDE.md` holding `# Project Rules\nKEEP THIS` → `setup.sh --claude --yes` → assert `KEEP THIS` survived and the CLAUDE block was added.

- [ ] **Step 2: Run** — Run: `bash tests/e2e.test.sh` → Expected: `ALL PASS`.

- [ ] **Step 3: Run the full suite** — Run: `for t in tests/*.test.sh; do echo "== $t =="; bash "$t" || exit 1; done` → Expected: every file ends `ALL PASS`.

- [ ] **Step 4: Commit** — `git add tests/e2e.test.sh && git commit -m "test(e2e): empty + brownfield + existing-CLAUDE install scenarios"`

---

## Self-Review (completed by plan author)

- **Spec coverage:** §3.1/§3.2 layout → Phases 2–4 + Task 5.4 manifest. §3.3 ownership classes → Task 5.4 `VENDOR_MANIFEST` + merge modes. §3.4 two-block AGENTS.md + single-source → Tasks 5.1/5.2. §3.5 loop brain → Phase 3. §3.6 playbooks+profile → Phase 4. §3.7 CLI re-publish + bootstrap order → Phase 1 (ordered 1.1→1.4) + `file://` dev path in tests. §3.8 setup+doctor → Phases 5–6. §3.9 strip list → Task 2.1 explicit allow/exclude. §3.10 NOTICE → Task 0. §4 out-of-scope (`update`/manifest, Windows `.ps1`) → not planned (correct).
- **Placeholder scan:** `OWNER/REPO` is an intentional, documented variable resolved in Task 1.3 (Global Constraints) — not a plan placeholder. No TBD/TODO content steps.
- **Type consistency:** `render_harness_block`/`render_loops_block` (5.1) consumed by `upsert_block` (5.2) and `setup.sh` (5.5); `detect_platform`/`download_cli` (5.3) consumed by 5.5/tests; `lay_down_files`/`merge_gitignore`/`init_db` (5.4) consumed by 5.5; `VENDOR_MANIFEST` defined in 5.4, used by `lay_down_files`. Names consistent across tasks.

## Open follow-ups (v2, not in this plan)
- `update` command + `.agent-kit/manifest.yml` (SHA/version/checksum re-sync).
- Windows `.ps1` parity incl. `--claude`.
- Additional first-class runtime profiles (Codex/Cursor) beyond the neutral playbooks.

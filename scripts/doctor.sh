#!/usr/bin/env bash
# doctor.sh — validate an installed harness + loops target. Exit 0 iff all checks pass.
set -uo pipefail

TARGET="."
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a dir}"; shift ;;
    --target=*) TARGET="${1#--target=}" ;;
    -h|--help) echo "usage: doctor.sh [--target DIR]"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done
TARGET="$(cd "$TARGET" && pwd)"
CLI="$TARGET/scripts/bin/harness-cli"
FAILURES=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

# 1. No unfilled placeholders.
check_placeholders() {
  local hits
  hits="$(grep -rn '{{[A-Z_]*}}' "$TARGET/AGENTS.md" "$TARGET/docs" "$TARGET/loops" "$TARGET/playbooks" 2>/dev/null | grep -v '/superpowers/')"
  if [ -z "$hits" ]; then ok "no unfilled {{PLACEHOLDER}}"; else bad "unfilled placeholders:"; echo "$hits" | sed 's/^/      /'; fi
}

# 2. Both managed blocks present in AGENTS.md.
check_blocks() {
  local m
  for m in '<!-- HARNESS:BEGIN -->' '<!-- HARNESS:END -->' '<!-- LOOPS:BEGIN -->' '<!-- LOOPS:END -->'; do
    grep -qF "$m" "$TARGET/AGENTS.md" 2>/dev/null && ok "AGENTS.md has $m" || bad "AGENTS.md missing $m"
  done
}

# 3. CLI version ⇄ release tag ⇄ schema agree (catches a stale binary or unapplied migration).
check_versions() {
  local v_cli v_tag s_high s_db
  v_cli="$(HARNESS_REPO_ROOT="$TARGET" "$CLI" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  v_tag="$(sed 's/^harness-cli-v//' "$TARGET/scripts/harness-cli-release-tag" 2>/dev/null | tr -d '[:space:]')"
  s_high="$(ls "$TARGET/scripts/schema" 2>/dev/null | grep -oE '^[0-9]+' | sort -n | tail -1)"
  s_high="$((10#${s_high:-0}))"
  s_db="$(HARNESS_REPO_ROOT="$TARGET" "$CLI" migrate 2>/dev/null | grep -oiE 'schema version: [0-9]+' | grep -oE '[0-9]+' | head -1)"
  if [ -n "$v_cli" ] && [ "$v_cli" = "$v_tag" ]; then ok "CLI version $v_cli matches release tag"; else bad "version/tag drift (cli='$v_cli' tag='$v_tag')"; fi
  if [ -n "$s_db" ] && [ "$s_high" = "$s_db" ]; then ok "schema files ($s_high) match DB schema ($s_db)"; else bad "schema drift (files=$s_high db='$s_db')"; fi
}

# 4. CLI binary is gitignored / not committed.
check_gitignore() {
  if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$TARGET" check-ignore scripts/bin/harness-cli >/dev/null 2>&1 \
      && ok "scripts/bin/harness-cli is gitignored" || bad "scripts/bin/harness-cli NOT gitignored"
  else
    grep -qF 'scripts/bin/harness-cli' "$TARGET/.gitignore" 2>/dev/null \
      && ok "scripts/bin/harness-cli listed in .gitignore (no git repo)" || bad "scripts/bin/harness-cli not in .gitignore"
  fi
}

# 5. The files the managed blocks point at actually resolve.
check_links() {
  local f miss=0
  for f in docs/HARNESS.md docs/FEATURE_INTAKE.md docs/CONTEXT_RULES.md docs/TRACE_SPEC.md \
           docs/TOOL_REGISTRY.md loops/ARCHITECTURE.md loops/BOUNDARY.md; do
    [ -e "$TARGET/$f" ] || { bad "managed block points at missing $f"; miss=1; }
  done
  [ "$miss" -eq 0 ] && ok "managed-block doc pointers resolve"
}

# 6. CLI is operational against the durable layer.
check_cli_runs() {
  HARNESS_REPO_ROOT="$TARGET" "$CLI" query matrix >/dev/null 2>&1 && ok "harness-cli query matrix runs" || bad "harness-cli query matrix failed"
  HARNESS_REPO_ROOT="$TARGET" "$CLI" audit >/dev/null 2>&1 && ok "harness-cli audit runs" || bad "harness-cli audit failed"
}

# 7. Loop README schemas present.
check_loops() {
  local f
  for f in loops/signals/README.md loops/docs/README.md loops/domains/README.md; do
    [ -e "$TARGET/$f" ] && ok "$f present" || bad "$f missing"
  done
}

echo "doctor: validating $TARGET"
check_placeholders
check_blocks
check_versions
check_gitignore
check_links
check_cli_runs
check_loops
echo ""
if [ "$FAILURES" -eq 0 ]; then echo "doctor: ALL CHECKS PASS"; exit 0; else echo "doctor: $FAILURES CHECK(S) FAILED"; exit 1; fi

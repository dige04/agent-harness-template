#!/usr/bin/env bash
# setup.sh — install the harness (proof) + loops (memory) template into a target repo.
# Idempotent: re-runnable. Downloads the checksum-verified CLI, lays down vendor-managed
# files, union-merges .gitignore, block-merges AGENTS.md (HARNESS + LOOPS), inits the DB.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"   # template repo root (local run-mode)

MODE="merge"; TARGET="."; DRY_RUN=0; CLAUDE=0; YES=0; FORCE=0

usage() {
  echo "usage: setup.sh [--merge|--override] [--force] [--dry-run] [--claude] [--yes] [--target DIR]"
}
while [ $# -gt 0 ]; do
  case "$1" in
    --merge) MODE="merge" ;;
    --override) MODE="override" ;;
    --force) FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --claude) CLAUDE=1 ;;
    --yes) YES=1 ;;
    --target) TARGET="${2:?--target needs a dir}"; shift ;;
    --target=*) TARGET="${1#--target=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# shellcheck source=lib/blocks.sh
source "$SCRIPT_DIR/lib/blocks.sh"
source "$SCRIPT_DIR/lib/merge_blocks.sh"
source "$SCRIPT_DIR/lib/cli_download.sh"
source "$SCRIPT_DIR/lib/layout.sh"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] install into: $TARGET  (mode=$MODE, claude=$CLAUDE)"
  echo "[dry-run] CLI: download $(detect_platform) -> $TARGET/scripts/bin/harness-cli (checksum-verified)"
  echo "[dry-run] vendor files: ${#VENDOR_MANIFEST[@]} manifest entries laid down"
  echo "[dry-run] AGENTS.md: upsert HARNESS + LOOPS blocks (project prose preserved)"
  echo "[dry-run] .gitignore: union-merge harness ignores"
  [ "$CLAUDE" -eq 1 ] && echo "[dry-run] CLAUDE.md: write @AGENTS.md bridge; lay down .claude/ profile"
  echo "[dry-run] DB: harness-cli init + migrate (HARNESS_REPO_ROOT=$TARGET)"
  exit 0
fi

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

# 1. CLI binary — hard-fail on download/checksum error.
download_cli "$TARGET/scripts/bin" || { echo "ERROR: CLI download/checksum failed" >&2; exit 1; }

# 2. Vendor-managed files.
lay_down_files "$SRC_ROOT" "$TARGET" "$MODE"

# 2b. Optional Claude profile (only with --claude).
if [ "$CLAUDE" -eq 1 ] && [ -d "$SRC_ROOT/.claude" ]; then
  SAVED_MANIFEST=("${VENDOR_MANIFEST[@]}")
  VENDOR_MANIFEST=(".claude")
  lay_down_files "$SRC_ROOT" "$TARGET" "$MODE"
  VENDOR_MANIFEST=("${SAVED_MANIFEST[@]}")
fi

# 3. .gitignore union (harness must-ignores only — never the template's own /target/, node_modules/).
GI_TMP="$(mktemp)"
printf '%s\n' 'harness.db' 'harness.db-*' 'scripts/bin/harness-cli' 'scripts/bin/harness-cli.exe' > "$GI_TMP"
merge_gitignore "$GI_TMP" "$TARGET/.gitignore"
rm -f "$GI_TMP"

# 4. AGENTS.md — create header if absent, then idempotently upsert both managed blocks.
AGENTS="$TARGET/AGENTS.md"
[ -e "$AGENTS" ] || printf '# Agent Instructions\n\n' > "$AGENTS"
upsert_block "$AGENTS" '<!-- HARNESS:BEGIN -->' '<!-- HARNESS:END -->' "$(render_harness_block)"
upsert_block "$AGENTS" '<!-- LOOPS:BEGIN -->'   '<!-- LOOPS:END -->'   "$(render_loops_block)"

# 5. Optional CLAUDE.md bridge (@AGENTS.md), preserving any existing project rules.
if [ "$CLAUDE" -eq 1 ]; then
  CLAUDE_MD="$TARGET/CLAUDE.md"
  [ -e "$CLAUDE_MD" ] || printf '# Project Rules\n\n' > "$CLAUDE_MD"
  upsert_block "$CLAUDE_MD" '<!-- CLAUDE-BRIDGE:BEGIN -->' '<!-- CLAUDE-BRIDGE:END -->' "$(render_claude_bridge)"
fi

# 6. Durable layer — hard-fail on init/migrate error.
init_db "$TARGET" || { echo "ERROR: harness-cli init/migrate failed" >&2; exit 1; }

echo "✓ Installed harness + loops into $TARGET (mode=$MODE, claude=$CLAUDE)"
echo "  Next: run scripts/doctor.sh --target \"$TARGET\" to validate."

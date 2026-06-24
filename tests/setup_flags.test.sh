#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/cli_download.sh"

[ -x "$ROOT/target/release/harness-cli" ] || { echo "  FAIL: build the CLI first (cargo build --release)"; exit 1; }
plat="$(detect_platform)"
rel=$(mk_fixture); cp "$ROOT/target/release/harness-cli" "$rel/harness-cli-$plat"
( cd "$rel" && shasum -a 256 "harness-cli-$plat" > "harness-cli-$plat.sha256" )
run_setup() { HARNESS_CLI_BASE_URL="file://$rel" bash "$ROOT/scripts/setup.sh" "$@"; }

# --dry-run: prints a plan, writes nothing.
td=$(mk_fixture)
run_setup --target "$td" --dry-run --yes >/tmp/aht_dry.out 2>&1; rc=$?
assert_eq "$rc" "0" "dry-run exits 0"
assert_contains /tmp/aht_dry.out 'dry-run' "dry-run prints a plan"
[ -e "$td/docs/HARNESS.md" ] && { echo "  FAIL: dry-run created files"; FAILED=1; } || echo "  ok: dry-run wrote no files"
[ -e "$td/harness.db" ]      && { echo "  FAIL: dry-run created a db"; FAILED=1; } || echo "  ok: dry-run created no db"

# --override: replaces a diverged vendor file and backs the old one up.
to=$(mk_fixture); ( cd "$to" && git init -q )
run_setup --target "$to" --merge --yes >/dev/null 2>&1
printf 'LOCAL EDIT\n' > "$to/docs/HARNESS.md"   # diverge a vendor-managed file
run_setup --target "$to" --override --yes >/dev/null 2>&1
assert_absent "$to/docs/HARNESS.md" 'LOCAL EDIT' "override replaced the diverged vendor file"
ls "$to/.harness-backup"/*/docs/HARNESS.md >/dev/null 2>&1 && echo "  ok: override backed up the prior file" || { echo "  FAIL: no backup written"; FAILED=1; }
grep -q 'LOCAL EDIT' "$to"/.harness-backup/*/docs/HARNESS.md 2>/dev/null && echo "  ok: backup holds the prior content" || { echo "  FAIL: backup content wrong"; FAILED=1; }
finish

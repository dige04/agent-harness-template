#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/cli_download.sh"

# Require the locally-built CLI (Phase 1.1 build) to stand up a file:// fake release.
if [ ! -x "$ROOT/target/release/harness-cli" ]; then
  echo "  FAIL: build the CLI first (cargo build --release)"; exit 1
fi
plat="$(detect_platform)"
rel=$(mk_fixture)
cp "$ROOT/target/release/harness-cli" "$rel/harness-cli-$plat"
( cd "$rel" && shasum -a 256 "harness-cli-$plat" > "harness-cli-$plat.sha256" )

tgt=$(mk_fixture)
( cd "$tgt" && git init -q )   # so `git check-ignore` can prove the binary is ignored

HARNESS_CLI_BASE_URL="file://$rel" bash "$ROOT/scripts/setup.sh" --target "$tgt" --merge --yes \
  || { echo "  FAIL: setup.sh exited non-zero"; FAILED=1; }

assert_file "$tgt/docs/HARNESS.md"     "docs system-of-record laid down"
assert_file "$tgt/loops/BOUNDARY.md"   "loops brain laid down"
assert_file "$tgt/playbooks/pr.md"     "playbooks laid down"
assert_file "$tgt/scripts/bin/harness-cli" "CLI binary installed"
[ -x "$tgt/scripts/bin/harness-cli" ] && echo "  ok: CLI executable" || { echo "  FAIL: CLI not executable"; FAILED=1; }
assert_contains "$tgt/AGENTS.md" '<!-- HARNESS:BEGIN -->' "AGENTS.md has HARNESS block"
assert_contains "$tgt/AGENTS.md" '<!-- LOOPS:BEGIN -->'   "AGENTS.md has LOOPS block"
assert_file "$tgt/harness.db" "durable DB created"
if git -C "$tgt" check-ignore scripts/bin/harness-cli >/dev/null 2>&1; then
  echo "  ok: CLI binary is gitignored"
else
  echo "  FAIL: CLI binary not gitignored"; FAILED=1
fi
finish

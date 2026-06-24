#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/cli_download.sh"

[ -x "$ROOT/target/release/harness-cli" ] || { echo "  FAIL: build the CLI first (cargo build --release)"; exit 1; }
plat="$(detect_platform)"
rel=$(mk_fixture); cp "$ROOT/target/release/harness-cli" "$rel/harness-cli-$plat"
( cd "$rel" && shasum -a 256 "harness-cli-$plat" > "harness-cli-$plat.sha256" )

run_setup() { HARNESS_CLI_BASE_URL="file://$rel" bash "$ROOT/scripts/setup.sh" "$@" >/dev/null 2>&1; }
run_doctor() { bash "$ROOT/scripts/doctor.sh" --target "$1" >/tmp/aht_e2e_doc.out 2>&1; }

echo "-- Case 1: empty repo + --claude --"
t1=$(mk_fixture); ( cd "$t1" && git init -q )
run_setup --target "$t1" --merge --claude --yes
run_doctor "$t1"; rc=$?; assert_eq "$rc" "0" "C1: doctor passes on empty install"
[ "$rc" -ne 0 ] && cat /tmp/aht_e2e_doc.out
assert_contains "$t1/CLAUDE.md" '@AGENTS.md' "C1: CLAUDE.md bridges @AGENTS.md"

echo "-- Case 2: brownfield (pre-existing AGENTS.md prose + docs/) --"
t2=$(mk_fixture); ( cd "$t2" && git init -q )
mkdir -p "$t2/docs"; printf 'be nice to each other\n' > "$t2/docs/CONTRIBUTING.md"
printf '# Agent Instructions\n\nCUSTOM PROSE\n' > "$t2/AGENTS.md"
run_setup --target "$t2" --merge --yes
assert_contains "$t2/AGENTS.md" 'CUSTOM PROSE' "C2: custom prose preserved"
assert_contains "$t2/AGENTS.md" '<!-- HARNESS:BEGIN -->' "C2: harness block added"
assert_contains "$t2/AGENTS.md" '<!-- LOOPS:BEGIN -->'   "C2: loops block added"
assert_contains "$t2/docs/CONTRIBUTING.md" 'be nice to each other' "C2: pre-existing docs/ file untouched"
run_doctor "$t2"; rc=$?; assert_eq "$rc" "0" "C2: doctor passes on brownfield"
[ "$rc" -ne 0 ] && cat /tmp/aht_e2e_doc.out

echo "-- Case 3: existing CLAUDE.md --"
t3=$(mk_fixture); ( cd "$t3" && git init -q )
printf '# Project Rules\nKEEP THIS\n' > "$t3/CLAUDE.md"
run_setup --target "$t3" --claude --yes
assert_contains "$t3/CLAUDE.md" 'KEEP THIS' "C3: existing CLAUDE rules preserved"
assert_contains "$t3/CLAUDE.md" '@AGENTS.md' "C3: CLAUDE bridge added"
run_doctor "$t3"; rc=$?; assert_eq "$rc" "0" "C3: doctor passes with existing CLAUDE.md"
[ "$rc" -ne 0 ] && cat /tmp/aht_e2e_doc.out
finish

#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/cli_download.sh"

[ -x "$ROOT/target/release/harness-cli" ] || { echo "  FAIL: build the CLI first (cargo build --release)"; exit 1; }
plat="$(detect_platform)"
rel=$(mk_fixture); cp "$ROOT/target/release/harness-cli" "$rel/harness-cli-$plat"
( cd "$rel" && shasum -a 256 "harness-cli-$plat" > "harness-cli-$plat.sha256" )

tgt=$(mk_fixture); ( cd "$tgt" && git init -q )
HARNESS_CLI_BASE_URL="file://$rel" bash "$ROOT/scripts/setup.sh" --target "$tgt" --merge --yes >/dev/null 2>&1

# Healthy install -> doctor exits 0
bash "$ROOT/scripts/doctor.sh" --target "$tgt" >/tmp/aht_doctor_ok.out 2>&1; rc=$?
assert_eq "$rc" "0" "doctor passes on healthy install"
[ "$rc" -ne 0 ] && cat /tmp/aht_doctor_ok.out

# Break it: inject an unfilled placeholder -> doctor must fail and report it
printf '\n{{TODO}}\n' >> "$tgt/AGENTS.md"
bash "$ROOT/scripts/doctor.sh" --target "$tgt" >/tmp/aht_doctor_bad.out 2>&1; rc=$?
[ "$rc" -ne 0 ] && echo "  ok: doctor fails on injected placeholder" || { echo "  FAIL: doctor passed despite placeholder"; FAILED=1; }
assert_contains /tmp/aht_doctor_bad.out 'TODO' "doctor reports the placeholder"
finish

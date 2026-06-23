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

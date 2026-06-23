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
# NB: no /s flag — dotall would let .* span newlines and delete HARNESS:END + the LOOPS block,
# making "loops block survived" unsatisfiable. We only want to mangle the single line it names.
perl -0pi -e 's/Operate the durable layer.*/STALE LINE/ if /HARNESS:BEGIN/../HARNESS:END/' "$f" 2>/dev/null || true
upsert_block "$f" '<!-- HARNESS:BEGIN -->' '<!-- HARNESS:END -->' "$(render_harness_block)"
assert_contains "$f" 'harness-cli query matrix' "C: harness refreshed"
assert_contains "$f" 'loops/BOUNDARY.md' "C: loops block survived"
assert_contains "$f" 'Project prose here.' "C: prose survived"
finish

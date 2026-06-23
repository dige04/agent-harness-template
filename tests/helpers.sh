#!/usr/bin/env bash
set -uo pipefail
FAILED=0
assert_eq()      { [ "$1" = "$2" ] && echo "  ok: $3" || { echo "  FAIL: $3 (got '$1' want '$2')"; FAILED=1; }; }
assert_contains(){ grep -q "$2" "$1" && echo "  ok: $3" || { echo "  FAIL: $3 ('$2' not in $1)"; FAILED=1; }; }
assert_absent()  { grep -q "$2" "$1" && { echo "  FAIL: $3 ('$2' unexpectedly in $1)"; FAILED=1; } || echo "  ok: $3"; }
assert_file()    { [ -e "$1" ] && echo "  ok: exists $1" || { echo "  FAIL: missing $1"; FAILED=1; }; }
mk_fixture()     { mktemp -d "${TMPDIR:-/tmp}/aht-fixture.XXXXXX"; }
finish()         { [ "$FAILED" -eq 0 ] && echo "ALL PASS" || { echo "TESTS FAILED"; exit 1; }; }

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

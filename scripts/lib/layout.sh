#!/usr/bin/env bash
# layout.sh — vendor-managed file lay-down, .gitignore union, and DB init.

# Vendor-managed payload (spec §3.3): overwritten on --override, skipped-if-present on --merge.
# Entries may be files OR directories (directories expand to their files). The --claude profile
# (.claude/) is laid down separately by setup.sh only when --claude is passed. AGENTS.md and
# .gitignore are NOT here — they are block-/union-merged. crates/, the release workflow, and
# build-harness-cli-release.sh are template-source-only and never ship.
VENDOR_MANIFEST=(
  "docs/HARNESS.md" "docs/FEATURE_INTAKE.md" "docs/CONTEXT_RULES.md" "docs/TRACE_SPEC.md"
  "docs/GLOSSARY.md" "docs/TOOL_REGISTRY.md" "docs/ARCHITECTURE.md"
  "docs/templates"
  "docs/product/README.md" "docs/stories/README.md" "docs/decisions/README.md"
  "loops/ARCHITECTURE.md" "loops/BOUNDARY.md" "loops/LOG.md"
  "loops/signals/README.md" "loops/docs/README.md" "loops/domains/README.md"
  "playbooks"
  "scripts/schema"
  "scripts/lib"
  "scripts/README.md"
  "scripts/setup.sh" "scripts/doctor.sh"
  "scripts/harness-cli-release-tag"
  "NOTICE" "LICENSE-harness"
)

# lay_down_files SRC TARGET MODE  (MODE = merge|override)
# merge: never touch an existing target file. override: back up existing to
# TARGET/.harness-backup/<ts>/ then replace. Missing source paths are skipped silently.
lay_down_files() {
  local src="$1" tgt="$2" mode="$3" entry f rel
  local backup="$tgt/.harness-backup/$(date +%Y%m%d-%H%M%S)"
  local files=()
  for entry in "${VENDOR_MANIFEST[@]}"; do
    if [ -d "$src/$entry" ]; then
      while IFS= read -r f; do files+=("${f#"$src"/}"); done < <(find "$src/$entry" -type f)
    elif [ -e "$src/$entry" ]; then
      files+=("$entry")
    fi
  done
  for rel in "${files[@]}"; do
    [ -e "$src/$rel" ] || continue
    if [ -e "$tgt/$rel" ]; then
      if [ "$mode" = "merge" ]; then
        continue
      else
        mkdir -p "$backup/$(dirname "$rel")"
        cp "$tgt/$rel" "$backup/$rel"
      fi
    fi
    mkdir -p "$tgt/$(dirname "$rel")"
    cp "$src/$rel" "$tgt/$rel"
  done
}

# merge_gitignore SRC TARGET — append each non-empty SRC line not already present (whole-line) in TARGET.
merge_gitignore() {
  local src="$1" tgt="$2" line
  [ -e "$tgt" ] || : > "$tgt"
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$line" ]; then continue; fi
    grep -qxF "$line" "$tgt" || printf '%s\n' "$line" >> "$tgt"
  done < "$src"
}

# init_db TARGET — initialize + migrate the durable layer rooted at TARGET.
init_db() {
  local target="$1"
  HARNESS_REPO_ROOT="$target" "$target/scripts/bin/harness-cli" init \
    && HARNESS_REPO_ROOT="$target" "$target/scripts/bin/harness-cli" migrate
}

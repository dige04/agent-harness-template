#!/usr/bin/env bash
# upsert_block FILE BEGIN END BLOCK — append BLOCK if BEGIN/END absent, else replace region in place.
upsert_block() {
  local file="$1" begin="$2" end="$3" block="$4" tmp
  tmp="$(mktemp)"
  if grep -qF "$begin" "$file" 2>/dev/null && grep -qF "$end" "$file"; then
    # Pass the (multi-line) block via ENVIRON, not -v: BSD/macOS awk rejects newlines in -v values.
    BLOCK="$block" awk -v b="$begin" -v e="$end" '
      index($0,b){print ENVIRON["BLOCK"]; skip=1; next}
      skip && index($0,e){skip=0; next}
      skip{next}
      {print}
    ' "$file" > "$tmp"
  else
    { cat "$file" 2>/dev/null; printf '\n%s\n' "$block"; } > "$tmp"
  fi
  mv "$tmp" "$file"
}

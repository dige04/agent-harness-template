#!/usr/bin/env bash
source "$(dirname "$0")/helpers.sh"
source "$(dirname "$0")/../scripts/lib/cli_download.sh"
p=$(detect_platform); echo "$p" | grep -qE '^(macos|linux)-(arm64|x64)$' && echo "  ok: platform $p" || { echo "  FAIL platform"; FAILED=1; }
# Build a fake release dir
rel=$(mk_fixture); plat=$(detect_platform)
printf 'FAKEBIN\n' > "$rel/harness-cli-$plat"
( cd "$rel" && shasum -a 256 "harness-cli-$plat" > "harness-cli-$plat.sha256" )
dest=$(mk_fixture)
HARNESS_CLI_BASE_URL="file://$rel" download_cli "$dest"
assert_file "$dest/harness-cli" "binary installed"
[ -x "$dest/harness-cli" ] && echo "  ok: executable" || { echo "  FAIL not executable"; FAILED=1; }
# Corrupt checksum -> must fail
bad=$(mk_fixture); printf 'OTHER\n' > "$bad/harness-cli-$plat"; printf 'deadbeef  harness-cli-'"$plat"'\n' > "$bad/harness-cli-$plat.sha256"
dest2=$(mk_fixture)
if HARNESS_CLI_BASE_URL="file://$bad" download_cli "$dest2" 2>/dev/null; then echo "  FAIL: bad checksum accepted"; FAILED=1; else echo "  ok: bad checksum rejected"; fi
finish

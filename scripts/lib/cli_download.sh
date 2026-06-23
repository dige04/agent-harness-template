#!/usr/bin/env bash
detect_platform() {
  local os arch; os="$(uname -s)"; arch="$(uname -m)"
  case "$os" in Darwin) os=macos;; Linux) os=linux;; *) echo "unsupported os: $os" >&2; return 1;; esac
  case "$arch" in arm64|aarch64) arch=arm64;; x86_64|amd64) arch=x64;; *) echo "unsupported arch: $arch" >&2; return 1;; esac
  echo "${os}-${arch}"
}
_fetch() { # _fetch URL DEST
  case "$1" in file://*) cp "${1#file://}" "$2";; *) curl -fsSL "$1" -o "$2";; esac
}
download_cli() {
  local dest="$1" plat tag base bin sum dir
  plat="$(detect_platform)" || return 1
  tag="$(cat "$(dirname "${BASH_SOURCE[0]}")/../harness-cli-release-tag")"
  base="${HARNESS_CLI_BASE_URL:-https://github.com/dige04/agent-harness-template/releases/download/$tag}"
  dir="$(mktemp -d)"; bin="harness-cli-$plat"; sum="$bin.sha256"
  _fetch "$base/$bin" "$dir/$bin" || { echo "download failed: $base/$bin" >&2; return 1; }
  _fetch "$base/$sum" "$dir/$sum" || { echo "checksum download failed" >&2; return 1; }
  ( cd "$dir" && shasum -a 256 -c "$sum" ) || { echo "CHECKSUM MISMATCH for $bin" >&2; return 1; }
  mkdir -p "$dest"; mv "$dir/$bin" "$dest/harness-cli"; chmod 755 "$dest/harness-cli"
}

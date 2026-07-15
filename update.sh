#!/usr/bin/env bash
# Re-pin flake.nix to a release version by re-prefetching each artifact's hash.
#
#   ./update.sh 0.1.4
#
# Bumps `version` and the three per-system `hash` values in flake.nix, then
# refreshes flake.lock. Run it from CI after a release is mirrored here, or by
# hand. Requires: nix (with flakes), sed.
set -euo pipefail

version="${1:?usage: ./update.sh <version>   e.g. ./update.sh 0.1.4}"
base="https://github.com/Soft-Machine-io/desktop-releases/releases/download/v${version}"

declare -A assets=(
  [x86_64-linux]="Soft-Machine-linux-x86_64.AppImage"
  [aarch64-darwin]="Soft-Machine-macos-arm64.dmg"
)

hash_for() {
  # base32 sha256 -> SRI, so it drops straight into flake.nix.
  local raw
  raw="$(nix-prefetch-url --type sha256 "$1" 2>/dev/null | tail -1)"
  nix hash convert --hash-algo sha256 --to sri "$raw"
}

for system in "${!assets[@]}"; do
  url="${base}/${assets[$system]}"
  echo "prefetching ${system}: ${assets[$system]}" >&2
  sri="$(hash_for "$url")"
  # Replace the hash on the line following this system's key in the artifacts
  # block (name line, then hash line).
  awk -v sys="\"${system}\"" -v sri="$sri" '
    $0 ~ sys" = {" { in_block = 1 }
    in_block && $1 == "hash" { sub(/"sha256-[^"]*"/, "\"" sri "\""); in_block = 0 }
    { print }
  ' flake.nix > flake.nix.tmp && mv flake.nix.tmp flake.nix
done

sed -i.bak -E "s/version = \"[0-9][^\"]*\";/version = \"${version}\";/" flake.nix && rm -f flake.nix.bak

nix flake lock --update-input nixpkgs >/dev/null 2>&1 || nix flake lock >/dev/null 2>&1 || true
echo "updated flake.nix to v${version}" >&2

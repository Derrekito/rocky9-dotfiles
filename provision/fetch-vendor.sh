#!/usr/bin/env bash
# Download the release files vendor/MANIFEST lists into vendor/, for
# install.sh (which never downloads). Run it on a machine with internet access,
# then copy vendor/ to the machine being set up (rsync). CI runs it too.
#
#   provision/fetch-vendor.sh
#
# Files already present with the right sha256 are left alone; anything that
# downloads with a different sha256 is discarded.
set -euo pipefail

vendor="$(cd "$(dirname "${BASH_SOURCE[0]}")/../vendor" && pwd)"
failed=0
while read -r name version file sha _bin url _; do
  dest="$vendor/$file"
  if [ -f "$dest" ] && echo "$sha  $dest" | sha256sum -c --quiet >/dev/null 2>&1; then
    echo "  ok   $file ($name $version)"
    continue
  fi
  tmp="$(mktemp "$vendor/.download.XXXXXX")"
  if curl -fsSL -o "$tmp" "$url" && echo "$sha  $tmp" | sha256sum -c --quiet >/dev/null 2>&1; then
    mv "$tmp" "$dest"
    chmod 644 "$dest"   # mktemp makes it 0600
    echo "  got  $file ($name $version)"
  else
    rm -f "$tmp"
    echo "FAILED: $file: download or sha256 ($url)" >&2
    failed=1
  fi
done < <(grep -v '^[[:space:]]*\(#\|$\)' "$vendor/MANIFEST")
exit $failed

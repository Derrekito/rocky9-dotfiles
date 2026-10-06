#!/usr/bin/env bash
# Fill vendor/ for install.sh, which never downloads. Run it on a machine
# with internet access, then copy vendor/ to the machine being set up (rsync).
# CI runs it too.
#
#   provision/fetch-vendor.sh
#
# 1. The release files vendor/MANIFEST lists. Files already present with the
#    right sha256 are left alone; a download with another sha256 is discarded.
# 2. Every Neovim plugin in nvim/plugins.lock, at its pinned commit (with git
#    submodules), as plain files in vendor/nvim-plugins/<name>/ plus a
#    <name>.commit naming that commit. The git clones they're copied from are
#    kept in ~/.cache/rocky9-dotfiles/plugin-src, so later runs only fetch
#    what changed. Plugins no longer in plugins.lock are removed.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
vendor="$root/vendor"
failed=0

echo "Release files"
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

echo "Neovim plugins (nvim/plugins.lock)"
out="$vendor/nvim-plugins"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/rocky9-dotfiles/plugin-src"
mkdir -p "$out" "$cache"
declare -A listed=()
while read -r name repo sha _ <&3; do
  case "$name" in '' | '#'*) continue ;; esac
  listed["$name"]=1
  if [ -d "$out/$name" ] && [ "$(cat "$out/$name.commit" 2>/dev/null)" = "$sha" ]; then
    printf '  ok   %-28s %s\n' "$name" "${sha:0:10}"
    continue
  fi
  src="$cache/$name"
  url="https://github.com/$repo.git"
  if [ ! -d "$src/.git" ]; then
    git clone --quiet "$url" "$src" </dev/null || { echo "FAILED: $name: clone $url" >&2; failed=1; continue; }
  elif [ "$(git -C "$src" remote get-url origin)" != "$url" ]; then
    git -C "$src" remote set-url origin "$url" # moved to a fork / renamed
  fi
  git -C "$src" cat-file -e "$sha^{commit}" 2>/dev/null ||
    git -C "$src" fetch --quiet --tags origin </dev/null || true
  git -C "$src" cat-file -e "$sha^{commit}" 2>/dev/null ||
    git -C "$src" fetch --quiet origin "$sha" </dev/null || true
  if ! git -C "$src" -c advice.detachedHead=false checkout --quiet --force "$sha" </dev/null ||
    ! git -C "$src" submodule update --init --recursive --quiet </dev/null; then
    echo "FAILED: $name: checkout $sha" >&2
    failed=1
    continue
  fi
  rm -rf "$out/$name.new"
  cp -a "$src" "$out/$name.new"
  find "$out/$name.new" -name .git -prune -exec rm -rf {} + # history isn't needed
  rm -rf "$out/$name"
  mv "$out/$name.new" "$out/$name"
  echo "$sha" >"$out/$name.commit"
  printf '  got  %-28s %s\n' "$name" "${sha:0:10}"
done 3<"$root/nvim/plugins.lock"

for dir in "$out"/*/; do
  name="$(basename "$dir")"
  if [ -z "${listed[$name]:-}" ]; then
    rm -rf "$out/$name" "$out/$name.commit"
    echo "  removed $name (not in plugins.lock)"
  fi
done
exit $failed

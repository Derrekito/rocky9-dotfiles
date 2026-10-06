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
#    submodules, without history), in one archive: vendor/nvim-plugins.tar.gz
#    holds nvim-plugins/<name>/ for each, plus nvim-plugins/COMMITS listing
#    "<name> <commit>". Git clones and unpacked copies are kept under
#    ~/.cache/rocky9-dotfiles, so later runs only fetch what changed.
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

echo "Neovim plugins (nvim/plugins.lock) -> vendor/nvim-plugins.tar.gz"
# One archive, so vendor/ stays a handful of files to copy. Each plugin is
# unpacked at its pinned commit in a working tree under ~/.cache, from the git
# clones kept there too, so later runs only fetch and copy what changed.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/rocky9-dotfiles"
clones="$cache/plugin-src"
tree="$cache/nvim-plugins"
mkdir -p "$clones" "$tree"
changed=0
declare -A listed=()
order=()
while read -r name repo sha _ <&3; do
  case "$name" in '' | '#'*) continue ;; esac
  listed["$name"]=1
  order+=("$name")
  if [ -d "$tree/$name" ] && [ "$(cat "$tree/$name.commit" 2>/dev/null)" = "$sha" ]; then
    printf '  ok   %-28s %s\n' "$name" "${sha:0:10}"
    continue
  fi
  src="$clones/$name"
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
  rm -rf "$tree/$name.new"
  cp -a "$src" "$tree/$name.new"
  find "$tree/$name.new" -name .git -prune -exec rm -rf {} + # history isn't needed
  rm -rf "$tree/$name"
  mv "$tree/$name.new" "$tree/$name"
  echo "$sha" >"$tree/$name.commit"
  changed=1
  printf '  got  %-28s %s\n' "$name" "${sha:0:10}"
done 3<"$root/nvim/plugins.lock"

for dir in "$tree"/*/; do
  name="$(basename "$dir")"
  if [ -z "${listed[$name]:-}" ]; then
    rm -rf "$tree/$name" "$tree/$name.commit"
    changed=1
    echo "  dropped $name (not in plugins.lock)"
  fi
done

archive="$vendor/nvim-plugins.tar.gz"
if [ $failed -ne 0 ]; then
  echo "  not writing $archive: some plugins failed" >&2
elif [ $changed -eq 1 ] || [ ! -f "$archive" ]; then
  # COMMITS: "<name> <commit>" per plugin; install-plugins.sh and doctor.sh
  # check it against plugins.lock.
  for name in "${order[@]}"; do echo "$name $(cat "$tree/$name.commit")"; done >"$tree/COMMITS"
  tar -C "$cache" -czf "$archive.new" nvim-plugins/COMMITS "${order[@]/#/nvim-plugins/}"
  mv "$archive.new" "$archive"
  chmod 644 "$archive"
  echo "  wrote $archive ($(du -h "$archive" | cut -f1))"
else
  echo "  ok   $archive"
fi
# The per-plugin directories earlier versions of this script left in vendor/.
rm -rf "$vendor/nvim-plugins"
exit $failed

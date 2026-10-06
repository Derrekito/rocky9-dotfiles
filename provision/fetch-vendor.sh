#!/usr/bin/env bash
# Fill vendor/ for install.sh, which never downloads. Run it on a machine
# with internet access, then copy vendor/ to the machine being set up (rsync).
# CI runs it too.
#
#   provision/fetch-vendor.sh
#
# 1. The release files vendor/MANIFEST lists. Files already present with the
#    right sha256 are left alone; a download with another sha256 is discarded.
# 2. Every plugin in nvim/plugins.lock and tmux/plugins.lock, at its pinned
#    commit (with git submodules, without history), one archive per lock:
#    vendor/nvim-plugins.tar.gz and vendor/tmux-plugins.tar.gz. Each holds
#    <set>/<name>/ per plugin plus <set>/COMMITS listing "<name> <commit>".
#    Symlinks are replaced by copies, so the archives unpack anywhere.
#    Git clones and unpacked copies are kept under ~/.cache/rocky9-dotfiles,
#    so later runs only fetch what changed.
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

cache="${XDG_CACHE_HOME:-$HOME/.cache}/rocky9-dotfiles"

# vendor_plugins LOCK NAME: pack every plugin LOCK pins ("name owner/repo
# commit" lines) into vendor/NAME.tar.gz, as NAME/<plugin>/ plus NAME/COMMITS
# ("<plugin> <commit>" lines). One archive keeps vendor/ a handful of files to
# copy. Each plugin is unpacked at its commit in a working tree under ~/.cache,
# from git clones kept there too (keyed by repo), so later runs only fetch and
# copy what changed.
vendor_plugins() {
  local lock="$1" set="$2"
  local tree="$cache/$set" clones="$cache/plugin-src" archive="$vendor/$set.tar.gz"
  local changed=0 bad=0 name repo sha src url dir
  local -A listed=()
  local order=()
  mkdir -p "$tree" "$clones"
  while read -r name repo sha _ <&3; do
    case "$name" in '' | '#'*) continue ;; esac
    listed["$name"]=1
    order+=("$name")
    if [ -d "$tree/$name" ] && [ "$(cat "$tree/$name.commit" 2>/dev/null)" = "$sha" ]; then
      printf '  ok   %-28s %s\n' "$name" "${sha:0:10}"
      continue
    fi
    src="$clones/${repo/\//__}"
    url="https://github.com/$repo.git"
    if [ ! -d "$src/.git" ]; then
      git clone --quiet "$url" "$src" </dev/null || { echo "FAILED: $name: clone $url" >&2; bad=1; continue; }
    fi
    git -C "$src" cat-file -e "$sha^{commit}" 2>/dev/null ||
      git -C "$src" fetch --quiet --tags origin </dev/null || true
    git -C "$src" cat-file -e "$sha^{commit}" 2>/dev/null ||
      git -C "$src" fetch --quiet origin "$sha" </dev/null || true
    if ! git -C "$src" -c advice.detachedHead=false checkout --quiet --force "$sha" </dev/null ||
      ! git -C "$src" submodule update --init --recursive --quiet </dev/null; then
      echo "FAILED: $name: checkout $sha" >&2
      bad=1
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
  done 3<"$lock"

  # Symlinks become copies of what they point at, so the archive unpacks on
  # filesystems without symlinks (a VM's shared folder: "cannot create
  # symbolic link ... protocol error"). The ones plugins ship are test
  # fixtures and docs. A dangling one is dropped.
  # Repeated until none are left: copying a directory can bring symlinks
  # inside it along.
  local link target
  while [ -n "$(find "$tree" -type l -print -quit)" ]; do
    while IFS= read -r -d '' link; do
      target="$(readlink -f "$link")"
      rm "$link"
      [ -e "$target" ] && cp -r "$target" "$link"
      changed=1
      echo "  copied symlink ${link#"$tree"/}"
    done < <(find "$tree" -type l -print0)
  done

  for dir in "$tree"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    if [ -z "${listed[$name]:-}" ]; then
      rm -rf "$tree/$name" "$tree/$name.commit"
      changed=1
      echo "  dropped $name (not in $(basename "$(dirname "$lock")")/plugins.lock)"
    fi
  done

  if [ $bad -ne 0 ]; then
    echo "  not writing $archive: some plugins failed" >&2
    failed=1
  elif [ $changed -eq 1 ] || [ ! -f "$archive" ]; then
    for name in "${order[@]}"; do echo "$name $(cat "$tree/$name.commit")"; done >"$tree/COMMITS"
    tar -C "$cache" -czf "$archive.new" "$set/COMMITS" "${order[@]/#/$set/}"
    mv "$archive.new" "$archive"
    chmod 644 "$archive"
    echo "  wrote $archive ($(du -h "$archive" | cut -f1))"
  else
    echo "  ok   $archive"
  fi
}

echo "Neovim plugins (nvim/plugins.lock) -> vendor/nvim-plugins.tar.gz"
vendor_plugins "$root/nvim/plugins.lock" nvim-plugins
echo "tmux plugins (tmux/plugins.lock) -> vendor/tmux-plugins.tar.gz"
vendor_plugins "$root/tmux/plugins.lock" tmux-plugins

# The per-plugin directories earlier versions of this script left in vendor/.
rm -rf "$vendor/nvim-plugins"
exit $failed

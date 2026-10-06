#!/usr/bin/env bash
# Install the plugins pinned in plugins.lock as native Neovim packages.
#
#   ./install-plugins.sh
#
# Plugins land in ~/.local/share/nvim/site/pack/plugins/{start,opt}/<name>.
# They come from ../vendor/nvim-plugins/<name>/ (copied in by hand, like the
# rest of vendor/; provision/fetch-vendor.sh makes them), never the network:
# each has a <name>.commit beside it, and a plugin whose commit isn't the one
# plugins.lock pins stops the install. Re-running is safe: a plugin is only
# replaced when its pinned commit changes. To change a pin, edit plugins.lock,
# re-run fetch-vendor.sh where it can download, copy vendor/ over, run this.
#
# Your own plugins (Derrekito/*) use a local checkout under ~/devel or
# ~/Projects when one exists, symlinked so edits are live (what lazy.nvim's
# dev block did). Otherwise they come from vendor/ like everything else.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lock="$here/plugins.lock"
vendor="$(cd "$here/.." && pwd)/vendor/nvim-plugins"
pack="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/plugins"
mkdir -p "$pack/start" "$pack/opt"

for tool in make gcc; do
  command -v "$tool" >/dev/null || echo "warning: '$tool' not found (sudo dnf install make gcc gcc-c++)" >&2
done

failed=()
declare -A wanted=()

# fd 3 for the lock file, so nothing inside the loop can eat its lines.
while read -r name repo sha kind _ <&3; do
  case "$name" in '' | '#'*) continue ;; esac
  wanted["$kind/$name"]=1
  dest="$pack/$kind/$name"
  if [ "$kind" = start ]; then other="$pack/opt/$name"; else other="$pack/start/$name"; fi
  # Moved between start/ and opt/ in plugins.lock.
  if [ -e "$other" ] && [ ! -e "$dest" ]; then mv "$other" "$dest"; fi

  if [ "${repo%%/*}" = Derrekito ]; then
    for root in "$HOME/devel" "$HOME/Projects"; do
      if [ -d "$root/$name" ]; then
        if [ -d "$dest" ] && [ ! -L "$dest" ]; then rm -rf "$dest"; fi
        ln -sfn "$root/$name" "$dest"
        printf '  dev  %-28s -> %s\n' "$name" "$root/$name"
        continue 2
      fi
    done
  fi

  # A dev symlink whose checkout has since gone away.
  if [ -L "$dest" ]; then rm "$dest"; fi

  src="$vendor/$name"
  if [ ! -d "$src" ] || [ ! -f "$src.commit" ]; then
    failed+=("$name (missing vendor/nvim-plugins/$name)")
    continue
  fi
  have="$(cat "$src.commit")"
  if [ "$have" != "$sha" ]; then
    failed+=("$name (vendor/nvim-plugins has ${have:0:10}, plugins.lock pins ${sha:0:10})")
    continue
  fi
  # Installed copies record their commit; replace only when it changes. (An
  # older install's git clone has no record, so it's replaced once.)
  if [ "$(cat "$dest/.vendor-commit" 2>/dev/null)" != "$sha" ]; then
    rm -rf "$dest.new"
    cp -a "$src" "$dest.new"
    echo "$sha" >"$dest.new/.vendor-commit"
    rm -rf "$dest"
    mv "$dest.new" "$dest"
    printf '  inst %-28s %s\n' "$name" "${sha:0:10}"
  else
    printf '  ok   %-28s %s\n' "$name" "${sha:0:10}"
  fi
done 3<"$lock"

# telescope-fzf-native is a small C library.
fzf="$pack/start/telescope-fzf-native.nvim"
if [ -d "$fzf" ]; then
  if make -C "$fzf" >/dev/null 2>&1; then
    echo "  built telescope-fzf-native"
  else
    failed+=("telescope-fzf-native (make; needs gcc + make)")
  fi
fi

# Help tags, so :help works for every plugin. -u NONE: don't load the config.
# install.sh puts its pinned Neovim first on PATH before calling this.
if command -v nvim >/dev/null; then
  nvim --headless -u NONE \
    -c "lua for _, d in ipairs(vim.fn.glob('$pack/*/*/doc', false, true)) do pcall(vim.cmd, 'helptags ' .. vim.fn.fnameescape(d)) end" \
    -c 'qa!' >/dev/null 2>&1 || true
fi

# Neovim loads everything in start/, so a plugin plugins.lock no longer lists
# (say, after an update dropped or renamed it) would still load. Move it out
# of the package path instead of deleting it.
unlisted="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/plugins-unlisted"
for dir in "$pack"/start/* "$pack"/opt/*; do
  [ -e "$dir" ] || [ -L "$dir" ] || continue
  rel="${dir#"$pack"/}"
  if [ -z "${wanted[$rel]:-}" ]; then
    dest="$unlisted/$rel.$(date +%Y%m%d%H%M%S)"
    mkdir -p "$(dirname "$dest")"
    mv "$dir" "$dest"
    echo "  moved $rel (not in plugins.lock) to $dest"
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  printf 'FAILED: %s\n' "${failed[@]}" >&2
  exit 1
fi
echo "Done. First launch compiles treesitter parsers and installs language servers (Mason) in the background."

#!/usr/bin/env bash
# Link these configs into $HOME and install pinned plugins. Run as your user,
# after provision/packages.sh. Safe to re-run: it moves things into place again
# and brings plugins back to their pins.
#
# Anything already in the way that isn't one of our links is moved aside to
# <name>.bak.<timestamp>, never deleted.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%s)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"

say() { printf '==> %s\n' "$*"; }

# link <target in repo> <path in $HOME>
link() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.bak.$stamp"
    echo "  moved existing $dest to $dest.bak.$stamp"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  linked $dest -> $src"
}

say "Linking configs"
link "$repo/nvim" "$config/nvim"
link "$repo/tmux" "$config/tmux"
link "$repo/bash/inputrc" "$HOME/.inputrc"
link "$repo/clang/clang-format" "$HOME/.clang-format"

link "$repo/hunk/config.toml" "$config/hunk/config.toml"
# Beamer theme parts for :MarkdownExport slides (TeX finds ~/texmf on its own).
# One link per file: kpathsea doesn't descend into a symlinked directory.
beamer="$HOME/texmf/tex/latex/beamer/RosePineMoon"
if [ -L "$beamer" ]; then
  mv "$beamer" "$beamer.bak.$stamp"
  echo "  moved existing $beamer to $beamer.bak.$stamp"
fi
for sty in "$repo"/texmf/beamer/RosePineMoon/*.sty; do
  link "$sty" "$beamer/$(basename "$sty")"
done

# Release binaries come from vendor/ (see vendor/README.md), never the network:
# vendor/MANIFEST lists each file with its sha256. install_release NAME checks
# the file and unpacks it to ~/.local/share/rocky9-dotfiles/NAME-VERSION, then
# links its binary into ~/.local/bin. Already-unpacked versions are kept.
manifest="$repo/vendor/MANIFEST"
install_release() {
  local want="$1" name version file sha bin _
  while read -r name version file sha bin _; do
    [ "$name" = "$want" ] && break
  done < <(grep -v '^[[:space:]]*\(#\|$\)' "$manifest")
  if [ "$name" != "$want" ]; then
    echo "FAILED: $want is not listed in $manifest" >&2
    exit 1
  fi
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/rocky9-dotfiles/$name-$version"
  local src="$repo/vendor/$file"
  if [ -x "$dir/$bin" ]; then
    echo "  ok   $name $version"
  elif [ ! -f "$src" ]; then
    echo "FAILED: missing vendor/$file ($name $version)." >&2
    echo "        Copy it in (rsync -av vendor/ <this machine>:${repo/#$HOME/\~}/vendor/)" >&2
    echo "        or run provision/fetch-vendor.sh on a machine that can download it." >&2
    exit 1
  elif ! echo "$sha  $src" | sha256sum -c --quiet >/dev/null 2>&1; then
    echo "FAILED: vendor/$file doesn't match its sha256 in vendor/MANIFEST" >&2
    echo "        (not $name $version? a different release under the same name?)" >&2
    exit 1
  else
    mkdir -p "$dir"
    case "$file" in
      *.tar.gz) tar -xzf "$src" -C "$dir" --strip-components=1 ;;
      *.gz) gunzip -c "$src" >"$dir/$bin" && chmod +x "$dir/$bin" ;;
    esac
    echo "  installed $name $version"
  fi
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$dir/$bin" "$HOME/.local/bin/$(basename "$bin")"
}

if [ "$(uname -m)" != x86_64 ]; then
  echo "FAILED: vendor/ has x86_64 builds; this is $(uname -m)" >&2
  exit 1
fi

say "Neovim"
# The official release build, not EPEL's 0.8: the config targets the latest
# Neovim. Unpacked in your home directory, so no root is needed.
install_release nvim

say "tree-sitter"
# The CLI tree-sitter-manager.nvim builds parsers with. 0.25.10 is the newest
# release whose binary runs on Rocky 9: 0.26+ needs glibc 2.35, Rocky 9 has 2.34.
install_release tree-sitter

say "hunk"
# Terminal diff viewer (github.com/modem-dev/hunk).
install_release hunk

# The rest of this script (plugin helptags, parsers) uses what was just
# installed, whatever PATH the caller had.
export PATH="$HOME/.local/bin:$PATH"

say "Hooking into ~/.bashrc"
line="[ -r \"$repo/bash/bashrc\" ] && source \"$repo/bash/bashrc\"  # rocky9-dotfiles"
touch "$HOME/.bashrc"
if grep -qF '# rocky9-dotfiles' "$HOME/.bashrc"; then
  # Re-point it, in case the repo moved.
  sed -i "\|# rocky9-dotfiles\$|c\\$line" "$HOME/.bashrc"
else
  printf '\n%s\n' "$line" >>"$HOME/.bashrc"
fi

local_dir="$config/rocky9-dotfiles"
if [ ! -e "$local_dir/local.sh" ]; then
  mkdir -p "$local_dir"
  cat >"$local_dir/local.sh" <<'LOCAL'
# Machine-specific shell settings, sourced at the end of rocky9-dotfiles'
# bashrc. Not part of the repo: work-only aliases, proxies, and anything else
# that shouldn't be published go here.
#
# PROMPT_THEME=moon         # moon, mocha, storm, ember
# PROMPT_GLYPHS=plain       # if the terminal font has no Nerd Font icons
# DOTFILES_TMUX_ON_SSH=0    # don't auto-attach tmux on SSH login
LOCAL
  echo "  created $local_dir/local.sh"
fi

say "Including shared git config"
# --fixed-value needs git 2.30+; Rocky 9 ships 2.39+.
for f in gitconfig delta.gitconfig; do
  git config --global --fixed-value --unset-all include.path "$repo/git/$f" 2>/dev/null || true
done
git config --global --add include.path "$repo/git/gitconfig"
if command -v delta >/dev/null; then
  git config --global --add include.path "$repo/git/delta.gitconfig"
fi

say "tmux plugins"
# From vendor/tmux-plugins.tar.gz (see vendor/README.md), never the network.
# Its tmux-plugins/COMMITS lists each plugin's commit; one that isn't the
# commit tmux/plugins.lock pins stops the install. An installed plugin is only
# replaced when its pin changes, and the archive only unpacked then.
plugins="$repo/tmux/plugins"
archive="$repo/vendor/tmux-plugins.tar.gz"
mkdir -p "$plugins"
failed=()
commits=""
unpacked=""
while read -r name repo_slug sha _ <&3; do
  case "$name" in '' | '#'*) continue ;; esac
  dest="$plugins/$name"
  if [ "$(cat "$dest/.vendor-commit" 2>/dev/null)" = "$sha" ]; then
    printf '  ok   %-28s %s\n' "$name" "${sha:0:10}"
    continue
  fi
  if [ ! -f "$archive" ]; then
    failed+=("$name (missing vendor/tmux-plugins.tar.gz)")
    continue
  fi
  [ -n "$commits" ] || commits="$(tar -xzOf "$archive" tmux-plugins/COMMITS 2>/dev/null)" || true
  have="$(awk -v n="$name" '$1 == n { print $2 }' <<<"$commits")"
  if [ "$have" != "$sha" ]; then
    failed+=("$name (vendor/tmux-plugins.tar.gz has ${have:-nothing}, tmux/plugins.lock pins ${sha:0:10})")
    continue
  fi
  if [ -z "$unpacked" ]; then
    unpacked="$(mktemp -d)"
    tar -xzf "$archive" -C "$unpacked"
  fi
  rm -rf "$dest.new"
  cp -a "$unpacked/tmux-plugins/$name" "$dest.new"
  echo "$sha" >"$dest.new/.vendor-commit"
  rm -rf "$dest"
  mv "$dest.new" "$dest"
  printf '  inst %-28s %s\n' "$name" "${sha:0:10}"
done 3<"$repo/tmux/plugins.lock"
[ -n "$unpacked" ] && rm -rf "$unpacked"
if [ ${#failed[@]} -gt 0 ]; then
  printf 'FAILED: %s\n' "${failed[@]}" >&2
  exit 1
fi

say "Neovim plugins"
"$repo/nvim/install-plugins.sh"

say "Treesitter parsers"
# Starting nvim kicks off the ensure_installed builds; wait for them (with the
# tree-sitter CLI above) before quitting, so they exist before first use.
nvim --headless -c 'lua require("tree-sitter-manager.installer").wait(require("tree-sitter-manager.config").cfg.ensure_installed, 900000)' \
  -c 'qa' 2>&1 | grep -v '^$' || true

say "Done. Open a new shell; nvim installs language servers on first launch."

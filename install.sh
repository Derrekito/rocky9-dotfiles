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

say "hunk"
# Terminal diff viewer (github.com/modem-dev/hunk). Release binary, pinned and
# checked against the release's SHA256SUMS; no npm or mise needed.
hunk_version=0.22.0
case "$(uname -m)" in
  x86_64)  hunk_asset=hunkdiff-linux-x64
           hunk_sha=5f280374f2ab0fc4c48266a9909ee1b0e0c59d77dd99a340f1c26f2125d2229b ;;
  aarch64) hunk_asset=hunkdiff-linux-arm64
           hunk_sha=da9f156427bce9a08609de66b310ba58f111ea31d6638ca7cdb08cf4a69d9e16 ;;
  *)       hunk_asset= ;;
esac
hunk_dir="${XDG_DATA_HOME:-$HOME/.local/share}/rocky9-dotfiles/hunk-$hunk_version"
if [ -z "$hunk_asset" ]; then
  echo "  skipped: no hunk build for $(uname -m)"
elif [ -x "$hunk_dir/hunk" ]; then
  echo "  ok   hunk $hunk_version"
else
  tmp="$(mktemp -d)"
  url="https://github.com/modem-dev/hunk/releases/download/v$hunk_version/$hunk_asset.tar.gz"
  if curl -fsSL -o "$tmp/hunk.tar.gz" "$url" &&
    echo "$hunk_sha  $tmp/hunk.tar.gz" | sha256sum -c --quiet; then
    mkdir -p "$hunk_dir"
    tar -xzf "$tmp/hunk.tar.gz" -C "$hunk_dir" --strip-components=1
    echo "  installed hunk $hunk_version"
  else
    echo "FAILED: hunk download or checksum ($url)" >&2
    rm -rf "$tmp"
    exit 1
  fi
  rm -rf "$tmp"
fi
if [ -x "$hunk_dir/hunk" ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$hunk_dir/hunk" "$HOME/.local/bin/hunk"
fi

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
plugins="$repo/tmux/plugins"
mkdir -p "$plugins"
failed=()
while read -r name repo_slug sha _ <&3; do
  case "$name" in '' | '#'*) continue ;; esac
  dest="$plugins/$name"
  if [ ! -d "$dest/.git" ]; then
    git clone --quiet --filter=blob:none "https://github.com/$repo_slug.git" "$dest" </dev/null ||
      { failed+=("$name (clone)"); continue; }
  fi
  git -C "$dest" cat-file -e "$sha^{commit}" 2>/dev/null ||
    git -C "$dest" fetch --quiet origin </dev/null || true
  if git -C "$dest" -c advice.detachedHead=false checkout --quiet "$sha" </dev/null; then
    printf '  ok   %-28s %s\n' "$name" "${sha:0:10}"
  else
    failed+=("$name (checkout $sha)")
  fi
done 3<"$repo/tmux/plugins.lock"
if [ ${#failed[@]} -gt 0 ]; then
  printf 'FAILED: %s\n' "${failed[@]}" >&2
  exit 1
fi

say "Neovim plugins"
"$repo/nvim/install-plugins.sh"

say "Treesitter parsers"
# Headless, so treesitter.lua compiles them synchronously before exiting.
nvim --headless -c 'qa' 2>&1 | grep -v '^$' || true

say "Done. Open a new shell; nvim installs language servers on first launch."

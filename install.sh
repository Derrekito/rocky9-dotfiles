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

# install_release NAME VERSION URL SHA256 [BIN]
# Download a pinned release (.tar.gz, or a single gzipped binary), check it
# against SHA256, unpack it to ~/.local/share/rocky9-dotfiles/NAME-VERSION,
# and link BIN (path inside it; default NAME) into ~/.local/bin. Skips the
# download when that version is already there.
install_release() {
  local name="$1" version="$2" url="$3" sha="$4" bin="${5:-$1}"
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/rocky9-dotfiles/$name-$version"
  if [ -x "$dir/$bin" ]; then
    echo "  ok   $name $version"
  else
    local tmp
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/download" "$url" &&
      echo "$sha  $tmp/download" | sha256sum -c --quiet; then
      mkdir -p "$dir"
      case "$url" in
        *.tar.gz) tar -xzf "$tmp/download" -C "$dir" --strip-components=1 ;;
        *.gz) gunzip -c "$tmp/download" >"$dir/$bin" && chmod +x "$dir/$bin" ;;
      esac
      echo "  installed $name $version"
    else
      echo "FAILED: $name download or checksum ($url)" >&2
      rm -rf "$tmp"
      exit 1
    fi
    rm -rf "$tmp"
  fi
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$dir/$bin" "$HOME/.local/bin/$(basename "$bin")"
}

case "$(uname -m)" in
  x86_64)  arch=x64 ;;
  aarch64) arch=arm64 ;;
  *)       arch= ;;
esac

say "Neovim"
# The official release build, not EPEL's 0.8: the config targets the latest
# Neovim. Unpacked in your home directory, so no root is needed.
nvim_version=0.12.5
case "$arch" in
  x64)   install_release nvim "$nvim_version" \
           "https://github.com/neovim/neovim/releases/download/v$nvim_version/nvim-linux-x86_64.tar.gz" \
           bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875 bin/nvim ;;
  arm64) install_release nvim "$nvim_version" \
           "https://github.com/neovim/neovim/releases/download/v$nvim_version/nvim-linux-arm64.tar.gz" \
           1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725 bin/nvim ;;
  *)     echo "FAILED: no Neovim release build for $(uname -m)" >&2; exit 1 ;;
esac

say "tree-sitter"
# The CLI tree-sitter-manager.nvim builds parsers with. 0.25.10 is the newest
# release whose binary runs on Rocky 9: 0.26+ needs glibc 2.35+, Rocky 9 has 2.34.
ts_version=0.25.10
case "$arch" in
  x64)   install_release tree-sitter "$ts_version" \
           "https://github.com/tree-sitter/tree-sitter/releases/download/v$ts_version/tree-sitter-linux-x64.gz" \
           8283ddba69253c698f6e987ba0e2f9285e079c8db4d36ebe1394b5bb3a0ebdfd ;;
  arm64) install_release tree-sitter "$ts_version" \
           "https://github.com/tree-sitter/tree-sitter/releases/download/v$ts_version/tree-sitter-linux-arm64.gz" \
           07fbff8ae0eeb0d3e496e14fc1a30dcc730cc2c97d70e601e5357f2e51958af5 ;;
  *)     echo "FAILED: no tree-sitter release build for $(uname -m)" >&2; exit 1 ;;
esac

say "hunk"
# Terminal diff viewer (github.com/modem-dev/hunk). Release binary, pinned and
# checked against the release's SHA256SUMS; no npm or mise needed.
hunk_version=0.22.0
case "$arch" in
  x64)   install_release hunk "$hunk_version" \
           "https://github.com/modem-dev/hunk/releases/download/v$hunk_version/hunkdiff-linux-x64.tar.gz" \
           5f280374f2ab0fc4c48266a9909ee1b0e0c59d77dd99a340f1c26f2125d2229b ;;
  arm64) install_release hunk "$hunk_version" \
           "https://github.com/modem-dev/hunk/releases/download/v$hunk_version/hunkdiff-linux-arm64.tar.gz" \
           da9f156427bce9a08609de66b310ba58f111ea31d6638ca7cdb08cf4a69d9e16 ;;
  *)     echo "  skipped: no hunk build for $(uname -m)" ;;
esac

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
# Starting nvim kicks off the ensure_installed builds; wait for them (with the
# tree-sitter CLI above) before quitting, so they exist before first use.
nvim --headless -c 'lua require("tree-sitter-manager.installer").wait(require("tree-sitter-manager.config").cfg.ensure_installed, 900000)' \
  -c 'qa' 2>&1 | grep -v '^$' || true

say "Done. Open a new shell; nvim installs language servers on first launch."

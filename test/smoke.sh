#!/usr/bin/env bash
# Check an installed setup: nvim starts without errors, tmux.conf loads, and
# the bash config sources cleanly. Run as the user install.sh ran for.
set -uo pipefail
status=0
fail() { echo "FAIL: $*" >&2; status=1; }

echo "--- nvim $(nvim --version | head -1)"
# Collect every message from startup, including the errors plugins.lua
# reports through vim.schedule, then quit.
out=$(nvim --headless \
  -c 'lua vim.defer_fn(function() io.stdout:write(vim.fn.execute("messages")) vim.cmd("qa!") end, 2000)' \
  2>&1)
echo "$out"
if grep -Eq 'E[0-9]+:|[Ee]rror|failed to load|stack traceback' <<<"$out"; then
  fail "nvim reported errors at startup"
fi

# Each plugin's module actually loads.
for mod in telescope cmp lspconfig mason nvim-treesitter conform lint aerial trouble harpoon; do
  nvim --headless -c "lua local ok, e = pcall(require, '$mod'); if not ok then io.stderr:write(e) vim.cmd('cq') end" -c 'qa!' 2>&1 ||
    fail "nvim: require('$mod')"
done

echo "--- go"
go version || fail "go"
dlv version 2>/dev/null | head -1 || fail "dlv"
ts="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/plugins/start/nvim-treesitter/parser"
for p in go gomod gosum gowork; do
  [ -f "$ts/$p.so" ] || fail "treesitter parser: $p"
done
# gopls attaches to a Go file. Only when Mason has built it (CI does that in
# a step before this; on a new machine it happens on first launch).
gopls="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/gopls"
if [ -x "$gopls" ]; then
  tmp=$(mktemp -d)
  printf 'module example.com/smoke\n\ngo 1.21\n' >"$tmp/go.mod"
  printf 'package main\n\nimport "fmt"\n\nfunc main() { fmt.Println("hi") }\n' >"$tmp/main.go"
  out=$(cd "$tmp" && nvim --headless main.go -c 'lua
    vim.wait(20000, function() return #vim.lsp.get_active_clients({ name = "gopls" }) > 0 end, 200)
    local ok = #vim.lsp.get_active_clients({ name = "gopls" }) > 0
    io.stdout:write(ok and "\ngopls attached\n" or "\ngopls did not attach\n")
    vim.cmd(ok and "qa!" or "cq")' 2>&1)
  grep -o 'gopls [a-z ]*' <<<"$out"
  grep -q 'gopls attached' <<<"$out" || fail "gopls"
  rm -rf "$tmp"
  [ -x "${gopls%/*}/goimports" ] || fail "goimports not built"
else
  echo "gopls not built yet (Mason builds it on first launch)"
fi

echo "--- devdocs.nvim"
# :DevdocsUpdate shells out to `python scripts/convert.py`; convert a tiny
# page with the system python to prove that path works (Rocky's 3.9 + bs4).
dd="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/plugins/start/devdocs.nvim"
tmp=$(mktemp -d)
mkdir -p "$tmp/pages"
printf '<h1>declare</h1><p>Declare <code>variables</code>.</p><pre>declare -a arr</pre>\n' >"$tmp/pages/t.html"
if out=$(python "$dd/scripts/convert.py" "$tmp" t --lang=bash 2>&1) && grep -q 'declare -a arr' <<<"$out"; then
  echo "converter ok ($(python --version 2>&1))"
else
  echo "$out"
  fail "devdocs converter"
fi
rm -rf "$tmp"
[ -n "$(ls -A "$dd/manuals/cpp" 2>/dev/null)" ] || fail "devdocs C++ manual submodule missing"

echo "--- $(tmux -V)"
tmux -L smoke -f /dev/null new-session -d
if ! out=$(tmux -L smoke source-file "$HOME/.config/tmux/tmux.conf" 2>&1) || [ -n "$out" ]; then
  echo "$out"
  fail "tmux.conf"
fi
# tmux-quad: four panes, each with its own prompt theme and border label.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmux -L smoke resize-window -x 200 -y 50 2>/dev/null
tmux -L smoke run-shell "$repo/bin/tmux-quad demo" >/dev/null 2>&1 || fail "tmux-quad"
labels=$(tmux -L smoke list-panes -t demo -F '#{@quad_label}' 2>/dev/null | sort | tr '\n' ' ')
[ "$labels" = "ember mocha moon storm " ] || fail "tmux-quad panes: '$labels'"
tmux -L smoke kill-server 2>/dev/null

echo "--- prompt"
tmp=$(mktemp -d)
git -C "$tmp" init -q && touch "$tmp/new"
out=$(cd "$tmp" && TERM=xterm-256color COLUMNS=100 bash -ic \
  '_p_build; printf "%s" "$_p_line1" | tr -d "\001\002" | sed "s/\x1b\[[0-9;]*m//g"' 2>&1)
echo "$out"
grep -q '?1' <<<"$out" || fail "prompt: no git status in '$out'"
rm -rf "$tmp"

echo "--- hunk"
"$HOME/.local/bin/hunk" --version || fail "hunk"

echo "--- bash"
if ! out=$(TERM=xterm-256color bash -ic 'type ta cdd mkvenv >/dev/null && echo ok' 2>&1) || [ "$(tail -1 <<<"$out")" != ok ]; then
  echo "$out"
  fail "bashrc"
fi

git config --get-all include.path | grep -qxF "$repo/git/gitconfig" || fail "git include.path"

[ $status -eq 0 ] && echo "All checks passed."
exit $status

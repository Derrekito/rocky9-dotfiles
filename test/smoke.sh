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

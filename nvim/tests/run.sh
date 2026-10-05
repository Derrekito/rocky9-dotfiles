#!/usr/bin/env bash
# Test runner for this Neovim config.
#
#   tests/run.sh           unit + smoke
#   tests/run.sh unit      unit specs only (isolated, no plugins)
#   tests/run.sh smoke     smoke specs only (the real config, all plugins)
#   tests/run.sh smoke tests/smoke/keymaps_spec.lua   one file
#
# Unit specs run under tests/minimal_init.lua via plenary's harness. Smoke
# specs run under the real init.lua, one fresh nvim per file, because
# plenary's harness forces --noplugin and lazy.nvim loads nothing under it.
# Shada/log/state go to a throwaway XDG_STATE_HOME so test runs leave no
# trace in your real editor state.
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1

state="$(mktemp -d)"
trap 'rm -rf "$state"' EXIT
export XDG_STATE_HOME="$state"

suite="${1:-all}"
shift || true
status=0

run_unit() {
  echo "==> unit"
  nvim --headless --noplugin -u tests/minimal_init.lua \
    -c "PlenaryBustedDirectory tests/unit { minimal_init = 'tests/minimal_init.lua', sequential = true, timeout = 60000 }" \
    || status=1
}

run_smoke() {
  echo "==> smoke"
  local files=("$@")
  if [ ${#files[@]} -eq 0 ]; then
    files=(tests/smoke/*_spec.lua)
  fi
  for f in "${files[@]}"; do
    echo "--- $f"
    timeout 300 nvim --headless -u "$root/init.lua" \
      -c "lua require('plenary.busted').run('$root/$f')" \
      || status=1
  done
}

case "$suite" in
  unit) run_unit ;;
  smoke) run_smoke "$@" ;;
  all) run_unit; run_smoke ;;
  *) echo "usage: $0 [unit|smoke|all] [files...]" >&2; exit 2 ;;
esac

exit $status

-- nvim-lint linter definitions for MISS_HIT (MATLAB), which nvim-lint does
-- not bundle. Lives outside the plugin spec so the output parsers can be
-- unit-tested without loading nvim-lint.
--
-- Both tools have no stdin mode, so append_fname = true passes the buffer's
-- real path: they operate on the file and walk up from it to find
-- miss_hit.cfg. Without it they run against cwd with no file and crash.
local M = {}

local sev = vim.diagnostic.severity

-- mh_style --brief output:
--   file:line:col: style: message
--   file: style: message            (file-level, no position)
function M.parse_style(output, _)
  local diagnostics = {}
  for line in output:gmatch("[^\n]+") do
    local f, lnum, col, msg = line:match("^(.-):(%d+):(%d+):%s*style:%s*(.*)$")
    if f then
      table.insert(diagnostics, {
        source = "mh_style",
        lnum = tonumber(lnum) - 1,
        col = tonumber(col),
        message = msg,
        severity = sev.WARN,
      })
    else
      f, msg = line:match("^(.-): style:%s*(.*)$")
      if f and not line:match("^MISS_HIT") then
        table.insert(diagnostics, {
          source = "mh_style",
          lnum = 0,
          col = 0,
          message = msg,
          severity = sev.WARN,
        })
      end
    end
  end
  return diagnostics
end

local lint_severity = {
  high = sev.ERROR,
  medium = sev.WARN,
  low = sev.INFO,
}

-- mh_lint --brief output:
--   file:line:col: check (severity): message [rule]
function M.parse_lint(output, _)
  local diagnostics = {}
  for line in output:gmatch("[^\n]+") do
    if not line:match("^MISS_HIT") then
      local lnum, col, level, msg = line:match("^.-:(%d+):(%d+):%s*%a+%s*%((%a+)%):%s*(.*)$")
      if lnum then
        table.insert(diagnostics, {
          source = "mh_lint",
          lnum = tonumber(lnum) - 1,
          col = tonumber(col),
          message = msg,
          severity = lint_severity[level] or sev.WARN,
        })
      end
    end
  end
  return diagnostics
end

M.mh_style = {
  cmd = "mh_style",
  stdin = false,
  append_fname = true,
  args = { "--brief" },
  stream = "stdout",
  ignore_exitcode = true,
  parser = M.parse_style,
}

M.mh_lint = {
  cmd = "mh_lint",
  stdin = false,
  append_fname = true,
  args = { "--brief" },
  stream = "stdout",
  ignore_exitcode = true,
  parser = M.parse_lint,
}

return M

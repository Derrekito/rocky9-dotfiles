-- Sync local indent options to the .clang-format that applies to the buffer.
--
-- cindent drives live (per-keystroke) indentation, but it has no idea what
-- IndentWidth/UseTab a project's .clang-format uses. This reads the *effective*
-- clang-format config for the buffer's own path (`--dump-config` resolves the
-- nearest .clang-format the same way formatting does) and sets sw/sts/ts/et to
-- match. Runs per-buffer, so different projects get different indent
-- automatically, and re-runs on demand if you change a .clang-format.

local M = {}

-- Parse the few keys we care about out of `clang-format --dump-config` YAML.
local function parse_config(lines)
  local cfg = {}
  for _, line in ipairs(lines) do
    local k, v = line:match("^(%w+):%s*(.+)$")
    if k then
      cfg[k] = v
    end
  end
  return cfg
end

function M.apply(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == "" then
    return
  end
  if vim.fn.executable("clang-format") == 0 then
    return
  end

  -- --assume-filename makes clang-format resolve the .clang-format relative to
  -- the buffer's real path even though we feed config on stdout, not the file.
  local out = vim.system({
    "clang-format",
    "--style=file",
    "--assume-filename=" .. fname,
    "--dump-config",
  }, { text = true }):wait()

  if out.code ~= 0 or not out.stdout then
    return
  end

  local cfg = parse_config(vim.split(out.stdout, "\n", { plain = true }))
  local width = tonumber(cfg.IndentWidth)
  if not width then
    return
  end

  local use_tab = cfg.UseTab and cfg.UseTab ~= "Never"
  local tabw = tonumber(cfg.TabWidth) or width

  vim.bo[bufnr].shiftwidth = width
  vim.bo[bufnr].softtabstop = use_tab and 0 or width
  vim.bo[bufnr].tabstop = use_tab and tabw or width
  vim.bo[bufnr].expandtab = not use_tab
end

-- :ClangFormatIndentSync — re-read .clang-format for the current buffer.
-- Use after editing a .clang-format without reopening the file.
vim.api.nvim_create_user_command("ClangFormatIndentSync", function()
  M.apply()
  vim.notify(
    ("clang-format indent: sw=%d ts=%d et=%s"):format(
      vim.bo.shiftwidth, vim.bo.tabstop, tostring(vim.bo.expandtab)
    ),
    vim.log.levels.INFO
  )
end, { desc = "Sync indent options to the buffer's .clang-format" })

return M

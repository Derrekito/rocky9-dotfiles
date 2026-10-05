-- Markdown helpers used by after/ftplugin/markdown.lua.
local M = {}

-- Flip a markdown buffer between rendered mode (render-markdown decorations
-- plus snacks inline images) and source mode (plain text, raw syntax visible).
function M.toggle_source(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local source = not vim.b[buf].markdown_source_mode
  vim.b[buf].markdown_source_mode = source

  local ok, rm = pcall(require, "render-markdown")
  if ok then
    vim.api.nvim_buf_call(buf, source and rm.buf_disable or rm.buf_enable)
  end

  -- plugins/snacks.lua makes snacks' image scan return nothing for a
  -- source-mode buffer; this just makes the change show up right away.
  if package.loaded["snacks.image"] then
    if source then
      Snacks.image.placement.clean(buf)
    else
      pcall(vim.api.nvim_exec_autocmds, "WinScrolled", {
        group = "snacks.image.inline." .. buf,
        buffer = buf,
      })
    end
  end

  vim.notify("Markdown: " .. (source and "source" or "rendered"), vim.log.levels.INFO)
  return source
end

-- Wrap the visual selection (charwise) in `left`..`right`. Returns the
-- 0-based (row, col) where `right` now starts.
function M.surround_visual(left, right)
  local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
  if s[2] > e[2] or (s[2] == e[2] and s[3] > e[3]) then
    s, e = e, s
  end
  local srow, scol, erow, ecol = s[2] - 1, s[3] - 1, e[2] - 1, e[3]
  -- getpos() is byte-based; include every byte of a multibyte last char.
  local last = vim.api.nvim_buf_get_lines(0, erow, erow + 1, true)[1]
  ecol = math.min(ecol + #vim.fn.strcharpart(last:sub(ecol), 0, 1) - 1, #last)
  if ecol < 1 then
    ecol = #last
  end
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  vim.api.nvim_buf_set_text(0, erow, ecol, erow, ecol, { right })
  vim.api.nvim_buf_set_text(0, srow, scol, srow, scol, { left })
  return erow, ecol + (srow == erow and #left or 0)
end

-- Wrap the word under the cursor in `left`..`right`.
function M.surround_word(left, right)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local s, e = 1, 0
  -- Find the \k+ run that contains (or starts right after) the cursor.
  while true do
    local ms, me = line:find("[%w_]+", e + 1)
    if not ms then
      return
    end
    if me >= col then
      s, e = ms, me
      break
    end
    e = me
  end
  vim.api.nvim_buf_set_text(0, row, e, row, e, { right })
  vim.api.nvim_buf_set_text(0, row, s - 1, row, s - 1, { left })
end

-- Jump to the next (dir = 1) or previous (dir = -1) ATX heading, skipping
-- `#` lines inside fenced code blocks.
function M.jump_heading(dir)
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local in_fence, headings = false, {}
  for i, l in ipairs(lines) do
    if l:match("^%s*```") or l:match("^%s*~~~") then
      in_fence = not in_fence
    elseif not in_fence and l:match("^#+%s") then
      headings[#headings + 1] = i
    end
  end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  for n = 1, vim.v.count1 do
    local target
    if dir > 0 then
      for _, h in ipairs(headings) do
        if h > cur then target = h break end
      end
    else
      for i = #headings, 1, -1 do
        if headings[i] < cur then target = headings[i] break end
      end
    end
    if not target then
      break
    end
    cur = target
    if n == 1 then
      vim.cmd("normal! m'")
    end
  end
  vim.api.nvim_win_set_cursor(0, { cur, 0 })
end

-- mmdc's stock "dark" theme is black boxes on grey; theme diagrams from the
-- rose-pine moon palette instead (inline previews and slide exports).
-- Written to a cache file because mmdc only takes theme variables via
-- -c <json>.
function M.mermaid_config()
  local p = require("rose-pine-moon").palette
  local path = vim.fn.stdpath("cache") .. "/mermaid-rose-pine.json"
  local cfg = {
    theme = "base",
    themeVariables = {
      darkMode = true,
      background = p.base,
      fontFamily = "sans-serif",
      primaryColor = p.overlay,
      primaryTextColor = p.text,
      primaryBorderColor = p.iris,
      secondaryColor = p.surface,
      secondaryTextColor = p.text,
      secondaryBorderColor = p.foam,
      tertiaryColor = p.highlight_med,
      tertiaryTextColor = p.text,
      tertiaryBorderColor = p.rose,
      lineColor = p.subtle,
      textColor = p.text,
      mainBkg = p.overlay,
      nodeBorder = p.iris,
      clusterBkg = p.surface,
      clusterBorder = p.highlight_high,
      edgeLabelBackground = p.surface,
      noteBkgColor = p.highlight_med,
      noteTextColor = p.text,
      noteBorderColor = p.gold,
      actorBkg = p.overlay,
      actorBorder = p.iris,
      actorTextColor = p.text,
      signalColor = p.subtle,
      signalTextColor = p.text,
    },
  }
  local json = vim.json.encode(cfg)
  local f = io.open(path, "r")
  local current = f and f:read("*a")
  if f then f:close() end
  if current ~= json then
    f = assert(io.open(path, "w"))
    f:write(json)
    f:close()
  end
  return path
end

return M

-- :MarkdownSlides — present the current markdown note as slides, inside nvim.
--
-- Each slide is shown in a plain markdown buffer, so render-markdown styling
-- and snacks' inline mermaid/math/images all apply as usual.
--
-- Slide boundaries: `---` lines (or `<!-- end_slide -->`) if the note has
-- any; otherwise every `#` / `##` heading starts a new slide. Frontmatter is
-- dropped. Presentation starts on the slide under the cursor.
--
--   n <Space> l <Right>   next          p <BS> h <Left>   previous
--   gg / G                first / last  e                 edit this slide
--   q <Esc>               quit
local M = {}

local WIDTH = 100 -- text columns; the rest is split into side margins

-- { { start = <1-based source line>, lines = {...} }, ... }
function M.split(lines)
  local first = 1
  if lines[1] and lines[1]:match("^%-%-%-%s*$") then
    for i = 2, #lines do
      if lines[i]:match("^%-%-%-%s*$") or lines[i]:match("^%.%.%.%s*$") then
        first = i + 1
        break
      end
    end
  end

  local function each(fn)
    local fenced = false
    for i = first, #lines do
      local l = lines[i]
      if l:match("^%s*```") or l:match("^%s*~~~") then
        fenced = not fenced
      end
      fn(i, l, fenced)
    end
  end

  local function is_break(l)
    return l:match("^%-%-%-+%s*$") or l:match("^%s*<!%-%-%s*end_slide%s*%-%->%s*$")
  end
  local explicit = false
  each(function(_, l, fenced) explicit = explicit or (not fenced and is_break(l) ~= nil) end)

  local slides, cur = {}, nil
  local function flush()
    if cur then
      while cur.lines[1] and cur.lines[1]:match("^%s*$") do
        table.remove(cur.lines, 1)
        cur.start = cur.start + 1
      end
      while cur.lines[#cur.lines] and cur.lines[#cur.lines]:match("^%s*$") do
        table.remove(cur.lines)
      end
      if #cur.lines > 0 then slides[#slides + 1] = cur end
    end
    cur = nil
  end
  each(function(i, l, fenced)
    if not fenced and explicit and is_break(l) then
      flush()
      return
    end
    if not fenced and not explicit and l:match("^##?%s") then
      flush()
    end
    cur = cur or { start = i, lines = {} }
    table.insert(cur.lines, l)
  end)
  flush()
  return slides
end

local state -- the one running presentation

local function render()
  local s = state
  local slide = s.slides[s.idx]
  vim.bo[s.buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, vim.list_extend({ "" }, vim.deepcopy(slide.lines)))
  vim.bo[s.buf].modifiable = false
  -- Park the cursor on the blank top line so a concealed diagram on the
  -- first content line isn't revealed by having the cursor on it.
  vim.api.nvim_win_set_cursor(s.win, { 1, 0 })
  vim.wo[s.win].winbar = ("%%#Comment#  %s%%=%d / %d  "):format(s.title:gsub("%%", "%%%%"), s.idx, #s.slides)
end

local function layout()
  local pad = math.max(2, math.floor((vim.o.columns - WIDTH) / 2))
  if vim.fn.exists("+statuscolumn") == 1 then
    vim.wo[state.win].statuscolumn = string.rep(" ", pad)
  else
    -- Neovim < 0.9 has no statuscolumn. An empty sign column (up to 18
    -- cells) plus fold column (up to 9) gives up to 27 cells of margin.
    local signs = math.min(9, math.floor(pad / 2))
    vim.wo[state.win].signcolumn = signs > 0 and ("yes:" .. signs) or "no"
    vim.wo[state.win].foldcolumn = tostring(math.min(9, pad - 2 * signs))
  end
end

local function go(i)
  state.idx = math.max(1, math.min(i, #state.slides))
  render()
end

function M.stop(edit)
  local s = state
  if not s then return end
  state = nil
  vim.o.laststatus, vim.o.showtabline = s.saved.laststatus, s.saved.showtabline
  pcall(vim.api.nvim_del_augroup_by_id, s.group)
  local line = s.slides[s.idx].start
  if vim.api.nvim_tabpage_is_valid(s.tab) and #vim.api.nvim_list_tabpages() > 1 then
    pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(s.tab))
  end
  if edit and vim.api.nvim_win_is_valid(s.src_win) then
    vim.api.nvim_set_current_win(s.src_win)
    vim.api.nvim_win_set_cursor(s.src_win, { line, 0 })
    vim.cmd("normal! zvzt")
  end
end

function M.start()
  if state then M.stop() end
  local src_buf, src_win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local slides = M.split(vim.api.nvim_buf_get_lines(src_buf, 0, -1, false))
  if #slides == 0 then
    vim.notify("MarkdownSlides: nothing to present", vim.log.levels.WARN)
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(src_win)[1]
  local idx = 1
  for i, sl in ipairs(slides) do
    if sl.start <= cursor then idx = i end
  end

  local file = vim.api.nvim_buf_get_name(src_buf)
  local title = file ~= "" and vim.fs.basename(file):gsub("%.md$", "") or "slides"

  vim.cmd("tabnew")
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  -- No grammar/lint marks on a slide (harper-ls, markdownlint attach to any
  -- markdown buffer). enable(false, {bufnr}) is 0.10+, disable(buf) older.
  if not pcall(vim.diagnostic.enable, false, { bufnr = buf }) then
    pcall(vim.diagnostic.disable, buf)
  end
  -- Named beside the source so relative image links still resolve.
  if file ~= "" then
    pcall(vim.api.nvim_buf_set_name, buf, vim.fs.joinpath(vim.fs.dirname(file), title .. " [slides]"))
  end
  for opt, val in pairs({ number = false, relativenumber = false, signcolumn = "no", cursorline = false,
    foldcolumn = "0", foldenable = false, colorcolumn = "", list = false, spell = false,
    wrap = true, linebreak = true, fillchars = "eob: " }) do
    vim.wo[win][opt] = val
  end

  state = {
    buf = buf, win = win, tab = vim.api.nvim_get_current_tabpage(),
    src_win = src_win, slides = slides, idx = idx, title = title,
    saved = { laststatus = vim.o.laststatus, showtabline = vim.o.showtabline },
    group = vim.api.nvim_create_augroup("UserMarkdownSlides", { clear = true }),
  }
  vim.o.laststatus, vim.o.showtabline = 0, 0
  vim.bo[buf].filetype = "markdown"
  layout()
  render()

  vim.api.nvim_create_autocmd("VimResized", { group = state.group, callback = layout })
  -- Leaving the tab any other way (:tabclose, :q) still restores the UI.
  vim.api.nvim_create_autocmd("BufWipeout", { group = state.group, buffer = buf, callback = function() M.stop() end })

  local function map(keys, fn)
    for _, k in ipairs(keys) do
      vim.keymap.set("n", k, fn, { buffer = buf, nowait = true })
    end
  end
  map({ "n", "<Space>", "l", "<Right>", "<PageDown>" }, function() go(state.idx + 1) end)
  map({ "p", "<BS>", "h", "<Left>", "<PageUp>" }, function() go(state.idx - 1) end)
  map({ "gg" }, function() go(1) end)
  map({ "G" }, function() go(#state.slides) end)
  map({ "q", "<Esc>" }, function() M.stop() end)
  map({ "e" }, function() M.stop(true) end)
end

return M

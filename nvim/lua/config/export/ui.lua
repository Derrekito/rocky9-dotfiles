-- Floating window for :MarkdownExport: pick a format, flip per-run options,
-- preview the exact commands, save the choices into frontmatter, convert.
local export = require("config.export")
local fm = require("config.export.frontmatter")

local M = {}

local ns = vim.api.nvim_create_namespace("markdown_export_ui")

local function short(path)
  return path and vim.fn.fnamemodify(path, ":~:.") or "—"
end

function M.open(src_buf)
  local src = vim.api.nvim_buf_get_name(src_buf)
  if src == "" then
    vim.notify("Export: save the note first", vim.log.levels.WARN)
    return
  end
  local meta = export.meta(src_buf)
  local ex = type(meta.export) == "table" and meta.export or {}
  local state = {
    format = export.formats[ex.format or ""] and ex.format or "pdf",
    overrides = { pdf = {}, docx = {}, slides = {} },
    show_cmd = false,
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local win

  local function resolved()
    return export.resolve(src, meta, state.format, state.overrides[state.format])
  end

  local function render()
    local o = resolved()
    local lines, hls = {}, {}
    local function line(text, groups)
      lines[#lines + 1] = text
      for _, g in ipairs(groups or {}) do
        hls[#hls + 1] = { #lines - 1, g[1], g[2], g[3] }
      end
    end
    local function label(text) return { { 2, 2 + #text, "Title" } } end

    line("")
    -- Format tabs: the selected one highlighted.
    local tabs, groups, col = "  ", {}, 2
    for i, f in ipairs(export.order) do
      local t = (" %d %s "):format(i, export.formats[f].label)
      groups[#groups + 1] = { col, col + #t, f == state.format and "PmenuSel" or "Pmenu" }
      tabs = tabs .. t .. "  "
      col = col + #t + 2
    end
    line(tabs, groups)
    line("")
    line(("  Profile   %s"):format(o.profile), label("Profile"))
    line(("  Output    %s"):format(short(o.out)), label("Output"))
    line(("  Template  %s"):format(short(o.template or o["reference-doc"] or "(pandoc default)")), label("Template"))
    local names = vim.tbl_map(vim.fs.basename, o.filters)
    line(("  Filters   %s"):format(#names > 0 and table.concat(names, ", ") or "none"), label("Filters"))
    line("")
    local function box(key, on, text)
      line(("  %s  [%s] %s"):format(key, on and "x" or " ", text), { { 2, 3, "Special" }, { 5, 8, on and "DiagnosticOk" or "Comment" } })
    end
    box("t", o.toc, "Table of contents")
    box("n", o["number-sections"], "Number sections")
    box("o", o.open, "Open when done")
    line("")
    line(("  c  %s Command"):format(state.show_cmd and "▾" or "▸"), { { 2, 3, "Special" } })
    if state.show_cmd then
      -- One flag (with its value) per line so long paths stay readable.
      for _, s in ipairs(vim.tbl_filter(function(st) return st.cmd ~= nil end, export.steps(o))) do
        local cur = "     $ " .. vim.fs.basename(s.cmd[1])
        for i = 2, #s.cmd do
          local a = s.cmd[i]
          if a:match("^%-") then
            line(cur, { { 0, -1, "Comment" } })
            cur = "         " .. a
          else
            cur = cur .. " " .. short(a)
          end
        end
        if s.stdout then cur = cur .. " > " .. short(s.stdout) end
        line(cur, { { 0, -1, "Comment" } })
      end
    end
    line("")
    line("  <CR> convert   1-3/<Tab> format   O output   w save to frontmatter   q close",
      { { 0, -1, "Comment" } })

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, h in ipairs(hls) do
      local e = h[3] < 0 and #lines[h[1] + 1] or math.min(h[3], #lines[h[1] + 1])
      vim.api.nvim_buf_set_extmark(buf, ns, h[1], h[2], { end_col = e, hl_group = h[4] })
    end

    local width = math.min(vim.o.columns - 6, 96)
    for _, l in ipairs(lines) do width = math.max(width, math.min(vim.fn.strdisplaywidth(l) + 2, vim.o.columns - 6)) end
    local height = math.min(#lines, vim.o.lines - 6)
    local cfg = {
      relative = "editor", width = width, height = height,
      row = math.floor((vim.o.lines - height) / 2) - 1, col = math.floor((vim.o.columns - width) / 2),
      border = "rounded", title = " Export " .. vim.fs.basename(src) .. " ", title_pos = "center", style = "minimal",
    }
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, cfg)
    else
      win = vim.api.nvim_open_win(buf, true, cfg)
      vim.wo[win].wrap = true
      vim.wo[win].cursorline = false
    end
  end

  local function close()
    if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  local function set(key, value)
    state.overrides[state.format][key] = value
    render()
  end
  local function toggle(key)
    local o = resolved()
    set(key, not o[key])
  end
  local function pick(i)
    state.format = export.order[(i - 1) % #export.order + 1]
    render()
  end
  local function index()
    for i, f in ipairs(export.order) do if f == state.format then return i end end
    return 1
  end

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true })
  end
  for i = 1, #export.order do map(tostring(i), function() pick(i) end) end
  map("<Tab>", function() pick(index() + 1) end)
  map("<S-Tab>", function() pick(index() - 1) end)
  map("t", function() toggle("toc") end)
  map("n", function() toggle("number-sections") end)
  map("o", function() toggle("open") end)
  map("c", function() state.show_cmd = not state.show_cmd render() end)
  map("O", function()
    vim.ui.input({ prompt = "Output (file or dir, note-relative): ", default = short(resolved().out), completion = "file" },
      function(v) if v and v ~= "" then set("output", v) end end)
  end)
  map("w", function()
    local new = vim.deepcopy(ex)
    new.format = state.format
    new[state.format] = type(new[state.format]) == "table" and new[state.format] or {}
    for k, v in pairs(state.overrides[state.format]) do new[state.format][k] = v end
    local lines = fm.with_export(vim.api.nvim_buf_get_lines(src_buf, 0, -1, false), new)
    vim.api.nvim_buf_set_lines(src_buf, 0, -1, false, lines)
    meta = export.meta(src_buf)
    ex = type(meta.export) == "table" and meta.export or {}
    state.overrides[state.format] = {}
    render()
    vim.notify("Export: saved choices to frontmatter (buffer not written yet)", vim.log.levels.INFO)
  end)
  map("<CR>", function()
    local o = resolved()
    close()
    if export.source_of(src_buf) then
      export.run(o)
    end
  end)
  map("q", close)
  map("<Esc>", close)

  render()
end

return M

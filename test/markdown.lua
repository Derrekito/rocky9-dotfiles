-- Markdown checks for test/smoke.sh, run as:  nvim --headless -c "luafile test/markdown.lua"
-- Prints one line per check and exits non-zero if any failed. Exports run only
-- when their tools are installed (pandoc: packages.sh; TeX/mermaid:
-- provision/export-tools.sh).
local failed = false
local function check(name, ok, detail)
  io.stdout:write(("%s %s%s\n"):format(ok and "ok  " or "FAIL", name, detail and (" (" .. detail .. ")") or ""))
  if not ok then failed = true end
end

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local note = dir .. "/note.md"
vim.fn.writefile({
  "---", "title: Smoke", "---", "",
  "# Heading", "", "- [ ] task", "- item", "",
  "```python", "print('hi')", "```", "",
  "```mermaid", "flowchart LR", "  A --> B", "```", "",
  "> [!NOTE]", "> callout", "",
  "## Second", "", "text",
}, note)
vim.cmd("edit " .. note)
vim.wait(1500)

-- render-markdown draws: its namespace has extmarks on the buffer.
local marks = 0
for name, id in pairs(vim.api.nvim_get_namespaces()) do
  if name:lower():find("render") then
    marks = marks + #vim.api.nvim_buf_get_extmarks(0, id, 0, -1, {})
  end
end
check("render-markdown draws", marks > 0, marks .. " extmarks")

local parsers = vim.api.nvim_get_runtime_file("parser/*.so", true)
local have = {}
for _, p in ipairs(parsers) do have[vim.fn.fnamemodify(p, ":t:r")] = true end
local missing = vim.tbl_filter(function(l) return not have[l] end, { "python", "yaml", "toml", "html", "css", "diff", "regex", "mermaid", "json", "bash" })
check("fence parsers", #missing == 0, #missing > 0 and ("missing " .. table.concat(missing, ",")) or nil)

-- bullets.vim continues a list on <CR>.
vim.api.nvim_win_set_cursor(0, { 8, 0 })
vim.api.nvim_feedkeys(vim.keycode("A<CR>next<Esc>"), "mx", false)
check("bullets continues lists", vim.api.nvim_buf_get_lines(0, 8, 9, false)[1] == "- next",
  vim.api.nvim_buf_get_lines(0, 8, 9, false)[1])
vim.cmd("silent! undo")

for _, cmd in ipairs({ "MarkdownExport", "MarkdownSlides", "MarkdownGraph" }) do
  check(":" .. cmd, vim.fn.exists(":" .. cmd) == 2)
end
check("<leader>mt mapped", vim.fn.maparg("<leader>mt", "n") ~= "")

-- marksman attaches (it aborts without libicu).
if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/bin/marksman") == 1 then
  vim.wait(15000, function() return #vim.lsp.get_clients({ name = "marksman" }) > 0 end, 200)
  check("marksman attaches", #vim.lsp.get_clients({ name = "marksman" }) > 0)
end

-- Link graph: a second note links to this one; the graph shows both.
vim.fn.writefile({ "# Other", "", "See [[note]]." }, dir .. "/other.md")
require("config.markdown_graph").open({})
local graph = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
check("graph", graph:find("flowchart LR", 1, true) ~= nil and graph:find('"other"', 1, true) ~= nil)
vim.cmd("tabclose")

-- Slides: start, step, quit.
require("config.markdown_slides").start()
local first = vim.wo.winbar
vim.api.nvim_feedkeys("n", "x", false)
check("slides step", vim.wo.winbar ~= first, vim.wo.winbar)
vim.api.nvim_feedkeys("q", "x", false)

local E = require("config.export")
local function export(format)
  local o = E.resolve(note, E.meta(vim.fn.bufnr(note)), format, { open = false })
  local missing_tools = E.missing_tools(E.steps(o))
  if #missing_tools > 0 then
    io.stdout:write(("skip %s export (not installed: %s)\n"):format(format, table.concat(missing_tools, ", ")))
    return
  end
  local done, ok = false, false
  E.run(o, function(r) ok, done = r, true end)
  vim.wait(240000, function() return done end, 200)
  local size = vim.fn.getfsize(o.out)
  check(format .. " export", ok and size > 0, ok and (size .. " bytes") or ("see " .. tostring(E.last_log)))
end
vim.cmd("buffer " .. vim.fn.bufnr(note))
export("docx")
export("slides")
export("pdf")

vim.fn.delete(dir, "rf")
vim.cmd(failed and "cq" or "qa!")

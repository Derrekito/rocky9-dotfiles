vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true

-- Fold by heading section (treesitter), everything open on load.
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt_local.foldlevel = 99

local md = require("config.markdown")
local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = true, desc = desc })
end

map("n", "<leader>mt", function() md.toggle_source() end, "Markdown: toggle rendered/source")

-- Heading navigation (replaces the runtime ftplugin's [[ ]], which only knows
-- h1-h5 and trips on `#` comments inside code blocks).
map({ "n", "x", "o" }, "]]", function() md.jump_heading(1) end, "Next heading")
map({ "n", "x", "o" }, "[[", function() md.jump_heading(-1) end, "Previous heading")

-- Inline formatting: normal mode wraps the word under the cursor, visual
-- mode wraps the selection.
for lhs, mark in pairs({ ["<leader>mb"] = { "**", "bold" }, ["<leader>mi"] = { "*", "italic" },
  ["<leader>mc"] = { "`", "code" }, ["<leader>m~"] = { "~~", "strikethrough" } }) do
  local m, what = mark[1], mark[2]
  map("n", lhs, function() md.surround_word(m, m) end, "Markdown: " .. what)
  map("x", lhs, function() md.surround_visual(m, m) end, "Markdown: " .. what)
end
map("x", "<leader>ml", function()
  -- [selection](|) with the cursor between the parens, ready for the URL.
  local row, col = md.surround_visual("[", "](")
  vim.api.nvim_buf_set_text(0, row, col + 2, row, col + 2, { ")" })
  vim.api.nvim_win_set_cursor(0, { row + 1, col + 2 })
  vim.cmd("startinsert")
end, "Markdown: link")

-- Link graph of the notes around this one (lua/config/markdown_graph.lua).
vim.api.nvim_buf_create_user_command(0, "MarkdownGraph", function(o)
  require("config.markdown_graph").command(o)
end, { bang = true, nargs = "?", desc = "Graph of linked notes (! = whole vault, N = hops)" })
map("n", "<leader>mG", "<cmd>MarkdownGraph<cr>", "Markdown: link graph")

-- Present this note as slides (lua/config/markdown_slides.lua).
vim.api.nvim_buf_create_user_command(0, "MarkdownSlides", function()
  require("config.markdown_slides").start()
end, { desc = "Present note as slides" })
map("n", "<leader>mp", "<cmd>MarkdownSlides<cr>", "Markdown: present as slides")

-- Export to PDF document / DOCX / PDF slides (lua/config/export/). No
-- argument opens the options window; frontmatter `export:` sets defaults.
vim.api.nvim_buf_create_user_command(0, "MarkdownExport", function(o)
  require("config.export").command(o)
end, { nargs = "?", complete = function() return { "pdf", "docx", "slides" } end,
  desc = "Export note (window, or pdf/docx/slides)" })
vim.api.nvim_buf_create_user_command(0, "MarkdownExportLog", function()
  local log = require("config.export").last_log
  if log and vim.uv.fs_stat(log) then vim.cmd("tabedit " .. vim.fn.fnameescape(log)) else vim.notify("No export log yet") end
end, { desc = "Open the last export's log" })
map("n", "<leader>me", "<cmd>MarkdownExport<cr>", "Markdown: export…")
map("n", "<leader>mP", "<cmd>MarkdownExport slides<cr>", "Markdown: export PDF slides")

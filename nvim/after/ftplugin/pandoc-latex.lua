-- ~/.config/nvim/after/ftplugin/pandoc-latex.lua
-- Pandoc LaTeX templates (*.latex, detected in lua/config/options.lua).
-- syntax/pandoc-latex.vim supplies TeX syntax as a base; this adds
-- highlighting for pandoc's $variable$ template language on top.

-- Rose Pine Moon colors. Highlight groups are global; the matches below are
-- what scope them to template buffers.
local p = require("rose-pine-moon").palette
vim.api.nvim_set_hl(0, "PandocVariable", { fg = p.gold })    -- $title$
vim.api.nvim_set_hl(0, "PandocFunction", { fg = p.foam })    -- ${whatever()}
vim.api.nvim_set_hl(0, "PandocConditional", { fg = p.iris }) -- $if(foo)$
vim.api.nvim_set_hl(0, "PandocLoop", { fg = p.pine })        -- $for(bar)$
vim.api.nvim_set_hl(0, "PandocDelimiter", { fg = p.love })   -- $

-- matchadd() is per *window*, not per buffer, so matches added here would
-- follow the window to whatever buffer it shows next. One global
-- BufWinEnter handler (the current window is always the one that just got a
-- buffer) adds them for templates and removes them for anything else.
local patterns = {
  { "PandocVariable", [[\$[a-zA-Z0-9._-]\+\$]] },
  { "PandocFunction", [[\${[a-zA-Z0-9._-]\+([^)]*)}]] },
  { "PandocConditional", [[\$if([a-zA-Z0-9._-]\+)\$]] },
  { "PandocConditional", [[\$else\$]] },
  { "PandocConditional", [[\$endif\$]] },
  { "PandocLoop", [[\$for([a-zA-Z0-9._-]\+)\$]] },
  { "PandocLoop", [[\$endfor\$]] },
  { "PandocDelimiter", [[\$]] },
}

local function sync_matches()
  local want = vim.bo.filetype == "pandoc-latex"
  local ids = vim.w.pandoc_latex_matches
  if want and not ids then
    ids = {}
    for _, m in ipairs(patterns) do
      table.insert(ids, vim.fn.matchadd(m[1], m[2], 10))
    end
    vim.w.pandoc_latex_matches = ids
  elseif not want and ids then
    for _, id in ipairs(ids) do
      pcall(vim.fn.matchdelete, id)
    end
    vim.w.pandoc_latex_matches = nil
  end
end

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("PandocLatexMatches", { clear = true }),
  callback = sync_matches,
})
sync_matches()

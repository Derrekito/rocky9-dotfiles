-- C++ specific settings (loads after all plugins)
-- Indent width/tabs are NOT hardcoded: they come from the .clang-format that
-- applies to this buffer (see lua/clang-format-indent.lua), so each project
-- gets its own settings and live cindent matches what clang-format produces.
-- Defaults below are a fallback if clang-format isn't available.
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab = true
vim.opt_local.cindent = true
vim.opt_local.cinkeys = "0{,0},0),0],:,0#,!^F,o,O,e"
vim.opt_local.indentexpr = ""

-- Set cindent options for proper brace indentation
vim.opt_local.cinoptions = "{1s,>2s,e-1s,^-1s,n-1s,:1s,=1s,g1s,h1s,p2s,t0,+1s,c3,(0,u0,)20,*30"

-- Pull indent width / tabs from the buffer's effective .clang-format.
require("clang-format-indent").apply()

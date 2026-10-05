-- Disable automatic text wrapping and indenting for LaTeX files
vim.opt_local.textwidth = 0
vim.opt_local.formatoptions:remove({ 't', 'c', 'a' })
vim.opt_local.wrap = false
vim.opt_local.linebreak = false  -- Critical: disable line breaking
vim.opt_local.breakindent = false
-- Indenting (autoindent, indentexpr) is turned off in after/indent/tex.lua.

-- Formatting is conform.nvim's job (latexindent, lua/plugins/conform.lua).

-- Disable automatic text wrapping and indenting for LaTeX files
vim.opt_local.textwidth = 0
vim.opt_local.formatoptions:remove({ 't', 'c', 'a' })
vim.opt_local.wrap = false
vim.opt_local.linebreak = false  -- Critical: disable line breaking
vim.opt_local.breakindent = false
vim.opt_local.indentexpr = ""  -- Disable vimtex indent expression
vim.opt_local.autoindent = false
vim.opt_local.smartindent = false

-- Formatting now handled by conform.nvim with proper latexindent config
-- texlab formatter is disabled in lsp-config.lua

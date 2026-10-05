-- No automatic indenting in LaTeX. This lives in after/indent, not
-- after/ftplugin: indent scripts (VimTeX's, or Neovim's own indent/tex.vim)
-- run after every ftplugin and would turn autoindent and an indentexpr
-- straight back on. after/indent is the one place that runs after them.
vim.opt_local.indentexpr = ""
vim.opt_local.autoindent = false
vim.opt_local.smartindent = false

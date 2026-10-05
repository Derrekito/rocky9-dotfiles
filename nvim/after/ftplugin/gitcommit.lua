-- Commit messages: Neovim's gitcommit ftplugin already sets textwidth=72 and
-- auto-wraps while typing. Its 'l' flag stops that for lines that were
-- already too long (pasted text), so drop it; then gq is only needed to
-- re-wrap text you've edited (gqip: this paragraph).
vim.opt_local.formatoptions:remove("l")
-- Show any line that is still over 72 instead of running it off-screen.
vim.opt_local.wrap = true
vim.opt_local.spell = true

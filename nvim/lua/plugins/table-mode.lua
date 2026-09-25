-- vim-table-mode, installed as an *optional* package (pack/plugins/opt/) and
-- loaded the first time a markdown buffer opens, like lazy.nvim's ft = markdown
-- did. Loading it globally at startup would also let its <leader>tt tableize
-- map replace Trouble's <leader>tt from the start.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  once = true,
  callback = function()
    vim.cmd("packadd vim-table-mode")
  end,
})

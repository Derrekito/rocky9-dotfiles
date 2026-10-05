-- Minimal init for unit tests: this config's lua/ on the rtp plus plenary,
-- and nothing else. No plugins load, so a unit spec exercises exactly one
-- module in isolation.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
vim.cmd("runtime plugin/plenary.vim")
vim.o.swapfile = false

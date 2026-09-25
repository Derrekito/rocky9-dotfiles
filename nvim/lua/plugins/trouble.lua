-- trouble.nvim v2.10.0 (v3 needs Neovim 0.9.2+).
require("trouble").setup({
  icons = false,                 -- Your original setting
  auto_open = false,             -- Don’t open on new diagnostics
  auto_close = false,            -- Don’t close when diagnostics clear
  auto_preview = true,           -- Preview diagnostic location
  debug = false,                 -- Disable debug mode
  -- Add other useful options
  mode = "document_diagnostics", -- Default mode (can be toggled)
  padding = true,                -- Add padding around the window
  indent_lines = true,           -- Indent guides under fold icons
})

-- Your keybindings. v3's `:Trouble diagnostics toggle` (all buffers) is
-- `:TroubleToggle workspace_diagnostics` in v2. next()/previous() below are
-- the v2 API already.
vim.keymap.set("n", "<leader>tt", "<cmd>TroubleToggle workspace_diagnostics<cr>", { desc = "Toggle Trouble" })
vim.keymap.set("n", "<leader>[d", function()
  require("trouble").next({ skip_groups = true, jump = true })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "]d", function()
  require("trouble").previous({ skip_groups = true, jump = true })
end, { desc = "Previous diagnostic" })

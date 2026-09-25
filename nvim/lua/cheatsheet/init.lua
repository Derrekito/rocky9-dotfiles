local M = {}

-- Main function to open the cheatsheet
function M.open()
  require("cheatsheet.ui").open_cheatsheet()
end

-- Setup function
function M.setup(opts)
  opts = opts or {}
  -- Define command
  vim.api.nvim_create_user_command("Cheatsheet", M.open, {})
  -- Define keymap
  vim.keymap.set("n", "<leader>cs", M.open, { desc = "Open cheatsheet" })
end

return M

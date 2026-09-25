-- diagnostic-picker.nvim plugin configuration
require("diagnostic-picker").setup({
  debug = false,
  debug_file = "/tmp/diagnostic-picker-debug.log",
  severities = {
    ERROR = true,
    WARN  = true,
    INFO  = true,
    HINT  = true,
  },
})

vim.keymap.set("n", "<leader>dg", function()
  require("diagnostic-picker").show()
end, { desc = "Diagnostic settings" })

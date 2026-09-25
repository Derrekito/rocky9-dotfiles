-- neotest, pinned to v3.4.7 (v4+ uses treesitter APIs that need 0.9).
-- https://github.com/nvim-neotest/neotest
require("neotest").setup({
  adapters = {
    require("neotest-python")
  }
})

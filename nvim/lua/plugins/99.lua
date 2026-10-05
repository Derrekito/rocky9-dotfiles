return {
  "ThePrimeagen/99",
  keys = {
    { "<leader>9v", mode = "v" },
    "<leader>9x", "<leader>9s", "<leader>9m", "<leader>9p",
  },
  config = function()
    local _99 = require("99")
    _99.setup({
      provider = _99.Providers.ClaudeCodeProvider,
      completion = {
        source = "cmp",
      },
    })

    vim.keymap.set("v", "<leader>9v", function()
      _99.visual()
    end)

    vim.keymap.set("n", "<leader>9x", function()
      _99.stop_all_requests()
    end)

    vim.keymap.set("n", "<leader>9s", function()
      _99.search()
    end)

    vim.keymap.set("n", "<leader>9m", function()
      require("99.extensions.telescope").select_model()
    end)

    vim.keymap.set("n", "<leader>9p", function()
      require("99.extensions.telescope").select_provider()
    end)
  end,
}

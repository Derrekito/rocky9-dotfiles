-- https://github.com/nvim-neotest/neotest?tab=readme-ov-file
return {
  "nvim-neotest/neotest",
  cmd = "Neotest",
  -- (FixCursorHold.nvim dropped: it works around a CursorHold bug fixed in
  -- Neovim 0.8, and neotest no longer asks for it.)
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-neotest/neotest-python"
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-python")
      }
    })
  end
}

return {
  {
    dir = vim.fn.stdpath("config") .. "/lua/cheatsheet",
    dependencies = { "nvim-telescope/telescope.nvim" },
    cmd = "Cheatsheet",
    keys = { "<leader>cs" },
    config = function()
      require("cheatsheet").setup()
    end,
  },
}

-- telescope.nvim, pinned to 0.1.8: the last release that supports Neovim 0.8.
require("telescope").setup {
  pickers = {
    find_files = {
      theme = "ivy"
    }
  },
  extensions = {
    fzf = {}
  }
}

-- fzf-native is a compiled C library (install-plugins.sh runs `make` for it).
-- If the build failed, keep going with telescope's built-in sorter.
local fzf_ok, fzf_err = pcall(require('telescope').load_extension, 'fzf')
if not fzf_ok then
  vim.schedule(function()
    vim.notify("telescope-fzf-native not built (run `make` in its plugin dir): " .. tostring(fzf_err),
      vim.log.levels.WARN)
  end)
end

vim.keymap.set("n", "<leader>ph", require('telescope.builtin').help_tags)
vim.keymap.set("n", "<leader>pf", require('telescope.builtin').find_files)
vim.keymap.set("n", "<leader>en", function()
  require('telescope.builtin').find_files {
    cwd = vim.fn.stdpath("config")
  }
end)
-- Browse installed plugin sources (the pack dir install-plugins.sh fills).
vim.keymap.set("n", "<leader>ep", function()
  require('telescope.builtin').find_files {
    cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "plugins")
  }
end)

--require "config.telescope.multigrep".setup()
vim.keymap.set("n", "<leader>mg", require("config.telescope.multigrep").live_multigrep, { desc = "Multi Grep" })

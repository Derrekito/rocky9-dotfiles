-- plugins/telescope.lua:
return {
  {
    'nvim-telescope/telescope.nvim',
    branch = 'master', -- 0.1.8 tag predates Neovim 0.12 (calls removed ts.ft_to_lang); track master
    cmd = 'Telescope',
    keys = { '<leader>ph', '<leader>pf', '<leader>en', '<leader>ep', '<leader>mg' },

    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' }
    },
    config = function()
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

      require('telescope').load_extension('fzf')

      vim.keymap.set("n", "<leader>ph", require('telescope.builtin').help_tags)
      vim.keymap.set("n", "<leader>pf", require('telescope.builtin').find_files)
      vim.keymap.set("n", "<leader>en", function()
        require('telescope.builtin').find_files {
          cwd = vim.fn.stdpath("config")
        }
      end)
      -- Browse the installed plugins' source: lazy.nvim's directory, or the
      -- pinned packages where there's no lazy.nvim (rocky9-dotfiles).
      vim.keymap.set("n", "<leader>ep", function()
        local data = vim.fn.stdpath("data")
        local lazy = vim.fs.joinpath(data, "lazy")
        require('telescope.builtin').find_files {
          cwd = vim.uv.fs_stat(lazy) and lazy or vim.fs.joinpath(data, "site", "pack", "plugins")
        }
      end)

      --require "config.telescope.multigrep".setup()
      vim.keymap.set("n", "<leader>mg", require("config.telescope.multigrep").live_multigrep, { desc = "Multi Grep" })
    end
  }
}

-- ~/.config/nvim/lua/plugins/tree.lua

return {
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",                   -- Optional: pins to latest version
    lazy = false,                    -- Load immediately to overwrite <leader>pv
    dependencies = {
      "nvim-tree/nvim-web-devicons", -- Optional: for file icons
    },
    keys = {
      -- Overwrite <leader>pv with nvim-tree toggle
      { "<leader>pv", "<cmd>NvimTreeToggle<CR>", desc = "Toggle Project View (nvim-tree)" },
    },
    -- Disable netrw before anything can source it (nvim-tree's advice: as
    -- early as possible). `init` runs at startup before any plugin loads;
    -- in `config` it ran too late to stop netrw cleanly.
    init = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
    config = function()

      -- Configure nvim-tree
      require("nvim-tree").setup({
        -- netrw is already off (init above). hijack_netrw would only try to
        -- clear netrw's FileExplorer autocmds, which then don't exist, and
        -- leave E216 in v:errmsg. Opening a directory (`nvim .`) still shows
        -- the tree via hijack_directories.
        disable_netrw = true,
        hijack_netrw = false,
        sort = {
          sorter = "case_sensitive",
        },
        view = {
          width = 30,
          side = "left",
        },
        renderer = {
          group_empty = true,
          highlight_git = true,
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        filters = {
          dotfiles = false,
        },
        git = {
          enable = true,
          ignore = false,
        },
        actions = {
          open_file = {
            quit_on_open = true,
          },
        },
      })
    end,
  },
}

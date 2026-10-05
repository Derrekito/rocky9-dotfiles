return {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" }, -- Optional but recommended
  cmd = "Trouble",
  keys = { "<leader>tt", "<leader>tn", "<leader>tp" },
  config = function()
    -- trouble v3 options. (v2's icons=false/mode/padding/indent are gone;
    -- icons=false in particular breaks v3's renderer, which indexes
    -- icons.indent.)
    require("trouble").setup({
      auto_open = false,    -- Don't open on new diagnostics
      auto_close = false,   -- Don't close when diagnostics clear
      auto_preview = true,  -- Preview diagnostic location
    })

    vim.keymap.set("n", "<leader>tt", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Toggle Trouble" })
    -- Step through the open Trouble list. Not ]d/[d: those are Neovim's
    -- built-in next/previous diagnostic and work without Trouble open.
    vim.keymap.set("n", "<leader>tn", function()
      require("trouble").next({ skip_groups = true, jump = true })
    end, { desc = "Trouble: next item" })
    vim.keymap.set("n", "<leader>tp", function()
      require("trouble").prev({ skip_groups = true, jump = true })
    end, { desc = "Trouble: previous item" })
  end
}

return {
  "tpope/vim-fugitive",
  name = "fugitive",
  -- Right after startup rather than on first :Git, so the statusline's
  -- branch shows up without having used fugitive yet.
  event = "VeryLazy",
  cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gread", "Gwrite", "Gedit", "GBrowse" },
  keys = { "<leader>gs" },
  init = function()
    -- Set here, not in config, so the statusline exists from the first
    -- frame; the branch part fills in once fugitive has loaded.
    vim.o.statusline = "%<%f %h%m%r%=%-14.(%l,%c%V%) %P %{exists('*FugitiveStatusline') ? FugitiveStatusline() : ''}"
  end,
  config = function()
    vim.keymap.set("n", "<leader>gs", vim.cmd.Git)

    local Derrekito_Fugitive = vim.api.nvim_create_augroup("Derrekito_Fugitive", {})

    local autocmd = vim.api.nvim_create_autocmd
    autocmd("BufWinEnter", {
      group = Derrekito_Fugitive,
      pattern = "*",
      callback = function()
        if vim.bo.ft ~= "fugitive" then
          return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local opts = { buffer = bufnr, remap = false }

        -- push
        vim.keymap.set("n", "<leader>p", function()
          vim.cmd.Git('push')
        end, opts)

        -- rebase always
        vim.keymap.set("n", "<leader>r", function()
          vim.cmd.Git('rebase -i')
        end, opts)

        -- log
        vim.keymap.set("n", "<leader>l", function()
          vim.cmd.Git(
            'log --pretty=format:"%C(yellow)%h %<(24)%C(red)%ad %<(18)%C(green)%an %C(reset)%s" --date=local --max-count=10')
        end, opts)
      end
    })
  end
}

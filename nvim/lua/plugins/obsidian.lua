-- obsidian-nvim/obsidian.nvim, the maintained community fork of
-- epwalsh/obsidian.nvim (unmaintained since 2024).
--
-- In vault notes: gf / <CR> follow links (<CR> also toggles checkboxes),
-- ]o [o jump between links, completion of [[links]] and #tags comes from its
-- built-in LSP (nvim-cmp picks it up via cmp-nvim-lsp), and
-- :Obsidian backlinks / links / quick_switch / search / tags / rename / ...
return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    -- `:Obsidian <subcommand>` only; the old :ObsidianFoo names go in 4.0.
    legacy_commands = false,

    workspaces = {
      { name = "personal",  path = "~/vaults/content/personal" },
      { name = "work",      path = "~/vaults/content/work" },
      { name = "templates", path = "~/vaults/content/Templates" },
    },

    link = { style = "markdown" },
    new_notes_location = "current_dir",

    completion = { min_chars = 2 },

    -- render-markdown.nvim draws checkboxes, bullets and links; obsidian's own
    -- UI layer draws them a second time on top (doubled bullets, misaligned
    -- checkboxes).
    ui = { enable = false },
  },
  config = function(_, opts)
    -- Only register vault workspaces whose directory exists on THIS machine:
    -- obsidian.nvim errors on a missing workspace path, and this config is
    -- shared with machines that have no ~/vaults. No vault, no setup.
    opts.workspaces = vim.tbl_filter(function(ws)
      return vim.fn.isdirectory(vim.fn.expand(ws.path)) == 1
    end, opts.workspaces)
    if #opts.workspaces == 0 then
      return
    end

    require("obsidian").setup(opts)

    -- Keep the old checkbox key in vault notes (<CR> on a checkbox also works).
    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("UserObsidianKeymaps", { clear = true }),
      pattern = "ObsidianNoteEnter",
      callback = function(ev)
        vim.keymap.set("n", "<leader>ch", "<cmd>Obsidian toggle_checkbox<cr>",
          { buffer = ev.buf, desc = "Obsidian: toggle checkbox" })
      end,
    })
  end,
}

-- aerial.nvim code outline, on its upstream nvim-0.8 branch.
require("aerial").setup({
  -- Prefer LSP (clangd) symbols; fall back to treesitter if no LSP.
  backends = { "lsp", "treesitter", "markdown", "man" },

  layout = {
    max_width = { 50, 0.3 }, -- wide enough for full signatures, capped at 30% of editor
    min_width = 30,
    default_direction = "right",
  },

  -- Show classes, methods, fields, etc. Trimmed of noise like local vars.
  filter_kind = {
    "Class",
    "Constructor",
    "Enum",
    "Function",
    "Interface",
    "Method",
    "Struct",
    "Field",
    "Property",
    "Constant",
  },

  show_guides = true,        -- tree guide lines
  autojump = true,           -- jump source to symbol when cursor moves in outline
  close_on_select = false,   -- keep the outline open after jumping
})

-- Toggle the outline panel; <leader>o jumps your cursor into it.
vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle!<cr>", { desc = "Toggle code outline" })
vim.keymap.set("n", "<leader>O", "<cmd>AerialToggle<cr>", { desc = "Outline + focus panel" })
-- Fuzzy-search the current file's symbols via Telescope (cleaner than lsp_document_symbols).
pcall(require("telescope").load_extension, "aerial")
vim.keymap.set("n", "<leader>fo", "<cmd>Telescope aerial<cr>", { desc = "Find symbol (outline)" })

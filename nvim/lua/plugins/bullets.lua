-- List editing in markdown: <CR>/o continue the list (an empty item ends it),
-- numbered lists renumber themselves, <C-t>/<C-d> (insert) or >>/<< indent.
return {
  "bullets-vim/bullets.vim",
  ft = { "markdown" },
  init = function()
    vim.g.bullets_enabled_file_types = { "markdown" }
    -- Toggle cycles only [ ] <-> [x] (default also has [.] [o] [O]).
    vim.g.bullets_checkbox_markers = " x"
    -- Indenting a numbered item makes it a dash bullet; dashes stay dashes.
    vim.g.bullets_outline_levels = { "num", "std-" }
    vim.g.bullets_delete_last_bullet_if_empty = 1
    -- Defaults minus <leader>x, which is chmod +x everywhere else; the
    -- checkbox toggle lives at <leader>mx with the other markdown maps.
    vim.g.bullets_set_mappings = 0
    vim.g.bullets_custom_mappings = {
      { "imap", "<cr>", "<Plug>(bullets-newline)" },
      { "inoremap", "<C-cr>", "<cr>" },
      { "nmap", "o", "<Plug>(bullets-newline)" },
      { "vmap", "gN", "<Plug>(bullets-renumber)" },
      { "nmap", "gN", "<Plug>(bullets-renumber)" },
      { "nmap", "<leader>mx", "<Plug>(bullets-toggle-checkbox)" },
      { "imap", "<C-t>", "<Plug>(bullets-demote)" },
      { "nmap", ">>", "<Plug>(bullets-demote)" },
      { "vmap", ">", "<Plug>(bullets-demote)" },
      { "imap", "<C-d>", "<Plug>(bullets-promote)" },
      { "nmap", "<<", "<Plug>(bullets-promote)" },
      { "vmap", "<", "<Plug>(bullets-promote)" },
    }
  end,
}

-- Treesitter parsers + highlighting via nvim-treesitter v0.8.5.2, the last
-- release supporting Neovim 0.8. (tree-sitter-manager.nvim needs a newer
-- Neovim.) Missing parsers are downloaded and compiled on first launch, which
-- needs a C/C++ compiler (gcc, gcc-c++) and git or curl + tar.
require("nvim-treesitter.configs").setup({
  ensure_installed = {
    "javascript", "typescript", "c", "cpp", "lua", "rust",
    "vim", "help", "query", "latex", "markdown", -- "help" is vimdoc's pre-0.9 name
    "markdown_inline", "make", "cuda"
  },
  -- Headless (install.sh, CI): compile parsers before exiting, so they exist
  -- before the first real launch. Interactive: compile in the background.
  sync_install = #vim.api.nvim_list_uis() == 0,
  highlight = {
    enable = true,
    -- Disable large file highlighting
    disable = function(_, buf)
      local max_filesize = 100 * 1024 -- 100 KB
      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
      return ok and stats ~= nil and stats.size > max_filesize
    end,
  },
})

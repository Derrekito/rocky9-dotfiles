return {
  {
    "romus204/tree-sitter-manager.nvim",
    config = function()
      require("tree-sitter-manager").setup({
        -- Auto-install parsers for these languages
        ensure_installed = {
          "javascript", "typescript", "c", "cpp", "lua", "rust",
          "vim", "vimdoc", "query", "latex", "markdown",
          "markdown_inline", "make", "cuda",
          -- Common fenced-code languages in markdown (yaml also covers
          -- frontmatter); without a parser a fence is one flat color.
          "python", "yaml", "toml", "html", "css", "diff", "regex", "sql",
          "mermaid", "json", "bash",
          "go", "gomod", "gosum", "gowork"
        },
      })

      -- Enable tree-sitter highlighting
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitterStart", { clear = true }),
        callback = function()
          local ok = pcall(vim.treesitter.start)
          if not ok then
            return
          end

          -- Disable large file highlighting
          local max_filesize = 100 * 1024 -- 100 KB
          local buf = vim.api.nvim_get_current_buf()
          local fname = vim.api.nvim_buf_get_name(buf)
          local ok_stat, stats = pcall(vim.uv.fs_stat, fname)
          if ok_stat and stats and stats.size > max_filesize then
            vim.treesitter.stop()
          end
        end,
      })
    end,
  },
}

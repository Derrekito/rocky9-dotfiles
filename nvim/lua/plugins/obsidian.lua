-- obsidian.nvim v3.9.0 (supports Neovim 0.8+).
local opts = {
  workspaces = {
    { name = "personal",  path = "~/vaults/content/personal" },
    { name = "work",      path = "~/vaults/content/work" },
    { name = "templates", path = "~/vaults/content/Templates" },
    --{ name = "pylabs",    path = "~/Projects/stochastic-python-labs" },
  },

  preferred_link_style = "markdown",  -- moved to top-level
  new_notes_location = "current_dir", -- moved to top-level

  completion = {
    nvim_cmp = true,
    min_chars = 2,
  },

  -- Optional: wiki_link_func if you want fancy links
  -- wiki_link_func = function(opts)
  --   return string.format("[[%s]]", opts.title)
  -- end,
}

-- Under lazy.nvim this only loaded once a markdown file opened. It now loads at
-- startup, so skip vaults that don't exist on this machine (obsidian.nvim errors
-- on a missing workspace path), and skip the plugin entirely if none do.
opts.workspaces = vim.tbl_filter(function(ws)
  return vim.fn.isdirectory(vim.fn.expand(ws.path)) == 1
end, opts.workspaces)
if #opts.workspaces == 0 then
  return
end

require("obsidian").setup(opts)

local function is_in_vault()
  local current_file = vim.api.nvim_buf_get_name(0)
  local normalized_file = vim.fn.fnamemodify(current_file, ":p")
  for _, workspace in ipairs(opts.workspaces) do
    local vault_path = vim.fn.expand(workspace.path)
    if normalized_file:find(vault_path, 1, true) == 1 then
      return true
    end
  end
  return false
end

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.md",
  callback = function()
    if is_in_vault() then
      vim.keymap.set("n", "gf", function()
        return require("obsidian").util.gf_passthrough()
      end, { noremap = false, expr = true, buffer = true })

      vim.keymap.set("n", "<leader>ch", function()
        return require("obsidian").util.toggle_checkbox()
      end, { buffer = true })
    end
  end,
})

-- Plugin setup, replacing lazy.nvim.
--
-- The plugins themselves are plain Neovim packages: install-plugins.sh clones
-- each one at the commit pinned in plugins.lock, into
--   ~/.local/share/nvim/site/pack/plugins/start/   (loaded at startup)
--   ~/.local/share/nvim/site/pack/plugins/opt/     (loaded with :packadd)
-- Neovim finds everything in start/ on its own, so all this file does is run
-- each lua/plugins/<name>.lua in dependency order.
--
-- Every file is loaded under pcall: a missing or broken plugin reports an
-- error and the rest of the config still loads (lazy.nvim did the same).
-- Plugins with nothing to configure (vim-be-good, FixCursorHold) have no file.

local order = {
  "colors",            -- colorscheme first, so later highlight tweaks land on it
  "treesitter",
  "completion",        -- nvim-cmp; before lsp-config (capabilities) and autopairs
  "lsp-config",        -- mason, mason-lspconfig, neodev, LuaSnip snippets, servers
  "telescope",         -- before aerial and cheatsheet, which build on it
  "aerial",
  "autopairs",
  "cheatsheet",
  "cloak",
  "conform",
  "devdocs",
  "diagnostic-picker",
  "fugitive",
  "harpoon",
  "nvim-dap",
  "nvim-lint",
  "obsidian",
  "table-mode",
  "tests",
  "tree",
  "trouble",
  "type-anim",
  "vimtex",
  "zen-mode",
}

for _, name in ipairs(order) do
  local ok, err = pcall(require, "plugins." .. name)
  if not ok then
    vim.schedule(function()
      vim.notify(("lua/plugins/%s.lua failed to load:\n%s"):format(name, err), vim.log.levels.ERROR)
    end)
  end
end

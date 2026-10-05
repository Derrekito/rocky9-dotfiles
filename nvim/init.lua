-- Entry point. Everything lives under lua/config/; plugin specs under lua/plugins/.
--
-- No plugin manager: install-plugins.sh puts the plugins pinned in
-- plugins.lock where Neovim loads them, and config.plugins runs the setup in
-- each lua/plugins/*.lua (same spec files as Derrekito/nvim).
--
-- Load order is deliberate:
--   1. keymaps   sets <leader> before any plugin maps against it.
--   2. plugins   runs every lua/plugins/*.lua setup, dependencies first.
--   3. options   after plugins, so our settings override plugin defaults.
--   4. lsp-*     compat shim and autorestart hook into LspAttach.
--   5. autocmds  diagnostics config + user autocmds, last so nothing clobbers it.
require("config.keymaps")
require("config.plugins").setup()
require("config.options")
require("lsp-autorestart")
require("lsp-compat-shim").setup()
require("config.autocmds")

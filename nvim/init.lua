-- Entry point. Everything lives under lua/config/; plugin setup under lua/plugins/.
--
-- This branch targets Neovim 0.8 (what EPEL ships for Rocky Linux 9). Plugins
-- are pinned in plugins.lock and installed by install-plugins.sh; there is no
-- plugin manager.
--
-- Load order is deliberate:
--   0. compat    backfills newer Neovim APIs this config and its plugins use.
--                Must come first. Does nothing on a newer Neovim.
--   1. keymaps   sets <leader> before any plugin maps against it.
--   2. plugins   runs each lua/plugins/*.lua setup, in dependency order.
--   3. options   after plugins, so our settings override plugin defaults.
--   4. lsp-*     compat shim and autorestart hook into LspAttach.
--   5. autocmds  diagnostics config + user autocmds, last so nothing clobbers it.
require("compat")
require("config.keymaps")
require("config.plugins")
require("config.options")
require("lsp-autorestart")
require("lsp-compat-shim").setup()
require("config.autocmds")

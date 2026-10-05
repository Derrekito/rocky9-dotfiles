-- Non-LSP tools installed through Mason: formatters, linters, and debug
-- adapters the config calls. (Language servers are mason-lspconfig's job,
-- see lua/plugins/lsp-config.lua.) Mason puts their binaries on Neovim's
-- PATH, so conform, nvim-lint and nvim-dap find them by name.
--
-- Everything else those plugins use comes from the system package manager
-- or pipx; tests/smoke/tools_spec.lua lists what is missing.
local M = {}

M.tools = {
  "stylua",    -- conform: lua
  "taplo",     -- conform: toml
  "goimports", -- conform: go (needs `go` on PATH)
  "hadolint",  -- nvim-lint: dockerfile
  "gitlint",   -- nvim-lint: gitcommit
  "debugpy",   -- nvim-dap: python adapter
  "cpptools",  -- nvim-dap: C/C++/CUDA adapter (OpenDebugAD7)
}

-- Install whichever of M.tools is missing, in the background. Safe to call
-- on every startup: installed packages are skipped, and it does nothing
-- without network beyond Mason's own "failed to refresh" notice.
function M.ensure_installed()
  local registry = require("mason-registry")
  registry.refresh(function()
    for _, name in ipairs(M.tools) do
      local ok, pkg = pcall(registry.get_package, name)
      if ok and not pkg:is_installed() and not pkg:is_installing() then
        pkg:install()
      end
    end
  end)
end

return M

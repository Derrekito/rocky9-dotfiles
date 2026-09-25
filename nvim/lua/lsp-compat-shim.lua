-- LSP deprecation compatibility shim.
--
-- Neovim 0.12 warns (slated for removal in 0.13) when a client method is called
-- with the dot form `client.supports_method(...)` instead of the colon form
-- `client:supports_method(...)`. nvim-lspconfig's clangd config still uses the
-- dot form (lua/lspconfig/configs/clangd.lua: `clangd_client.supports_method`),
-- and there is no released upstream fix as of 2026-06. That dot call is the sole
-- source of the "client.supports_method is deprecated" + "position_encoding ...
-- make_position_params" prompts seen on clangd attach and in Telescope LSP pickers.
--
-- Rather than suppress the message or edit plugin files (wiped by :Lazy sync),
-- we re-wrap `supports_method` PER CLIENT so the dot form still works but routes
-- straight to the real method without the vim.deprecate call. This lives in our
-- own config (survives updates), fixes the actual call rather than hiding it, and
-- auto-noops once Neovim removes the underlying method (pcall-guarded).
--
-- DELETE THIS MODULE once nvim-lspconfig ships a clangd config using the colon
-- form (track: the `supports_method` call in its clangd.lua).

local M = {}

local function rewrap(client)
  if not client or client.__compat_supports_method then
    return
  end
  -- The metatable method (colon form) does the real work and never warns.
  local mt = getmetatable(client)
  local real = mt and mt.supports_method
  if type(real) ~= "function" then
    return
  end
  -- Replace the instance's dot-form wrapper: accept either call form, always
  -- forward to the real method as `real(client, ...)`, never emitting deprecate.
  client.supports_method = function(first, ...)
    if first == client then
      return real(first, ...)
    end
    return real(client, first, ...)
  end
  client.__compat_supports_method = true
end

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("LspCompatShim", { clear = true }),
    callback = function(args)
      pcall(function()
        rewrap(vim.lsp.get_client_by_id(args.data.client_id))
      end)
    end,
  })
  -- Cover any clients that attached before this module loaded.
  pcall(function()
    for _, c in ipairs(vim.lsp.get_clients()) do
      rewrap(c)
    end
  end)
end

return M

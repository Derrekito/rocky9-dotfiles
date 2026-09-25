-- Reload the buffer to re-attach LSP clients, but never error on (or discard)
-- unsaved changes. Bare `:edit` raises E37 when the buffer is modified; guard
-- on 'modified' so a dirty buffer is simply skipped instead of crashing the
-- scheduled callback.
local function reload_for_lsp()
  if vim.bo.modified then
    vim.notify("LSP restart: buffer modified, skipping reload (save to re-attach)", vim.log.levels.INFO)
    return
  end
  vim.cmd("edit")
end

local function restart_lsp()
  -- Force-stop so a hung/slow server can't linger and accumulate duplicate
  -- processes across repeated restarts. The second arg to stop() requests
  -- force-kill rather than a graceful (and sometimes-ignored) shutdown.
  for _, client in ipairs(vim.lsp.get_clients()) do
    vim.lsp.stop_client(client.id, true)
  end
  vim.defer_fn(reload_for_lsp, 500)
end

-- Own `:LspRestart` so it works regardless of nvim-lspconfig load timing.
vim.api.nvim_create_user_command("LspRestart", restart_lsp, {
  desc = "Stop all LSP clients and re-attach by reloading the buffer",
})

local clangd_watcher = nil
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "clangd" then return end
    if clangd_watcher then return end

    local root = client.config.root_dir
    if not root then return end

    local w = vim.uv.new_fs_event()
    if not w then return end

    w:start(root .. "/.clangd", {}, vim.schedule_wrap(function()
      restart_lsp()
    end))
    clangd_watcher = w
  end,
})

-- :LspRestart, plus an automatic restart of clangd whenever its project's
-- .clangd file changes (diagnostic-picker writes it).
local M = {}

-- Reload the buffer to re-attach LSP clients, but never error on (or discard)
-- unsaved changes. Bare `:edit` raises E37 when the buffer is modified, and
-- E32 in a buffer with no file (nvim-tree, help, a scratch buffer); skip both
-- instead of crashing the scheduled callback.
function M.reload_for_lsp()
  if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" then
    return
  end
  if vim.bo.modified then
    vim.notify("LSP restart: buffer modified, skipping reload (save to re-attach)", vim.log.levels.INFO)
    return
  end
  vim.cmd("edit")
end

function M.restart()
  -- Ask for a clean shutdown, force-kill after 2 s so a hung server can't
  -- linger and pile up duplicate processes across restarts. Not an
  -- immediate force-kill: clangd then exits 1 ("Client clangd quit with exit
  -- code 1" on every restart), and killing it mid-write can corrupt its
  -- background index.
  for _, client in ipairs(vim.lsp.get_clients()) do
    client:stop(2000)
  end
  vim.defer_fn(M.reload_for_lsp, 500)
end

-- Own `:LspRestart` so it works regardless of nvim-lspconfig load timing.
vim.api.nvim_create_user_command("LspRestart", M.restart, {
  desc = "Stop all LSP clients and re-attach by reloading the buffer",
})

-- One watcher per clangd root. The watch is on the root *directory*, not on
-- .clangd itself: a file watch can't start while .clangd doesn't exist yet,
-- and editors that save by rename-over leave a file watch pointing at the
-- dead inode after the first save. Bursts of events (one save can emit
-- several) collapse into a single restart.
local watchers = {}
local pending = false

function M.on_root_event(filename)
  if filename ~= ".clangd" or pending then
    return
  end
  pending = true
  vim.defer_fn(function()
    pending = false
    M.restart()
  end, 200)
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("LspAutoRestart", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "clangd" then return end

    local root = client.root_dir or client.config.root_dir
    if not root or watchers[root] then return end

    local w = vim.uv.new_fs_event()
    if not w then return end
    local ok = w:start(root, {}, vim.schedule_wrap(function(err, filename)
      if not err then M.on_root_event(filename) end
    end))
    if ok then
      watchers[root] = w
    else
      w:close()
    end
  end,
})

return M

-- Backfills for Neovim 0.9/0.10/0.11 APIs, so this config (and the plugins it
-- pins) runs on Neovim 0.8, which is what EPEL ships for Rocky Linux 9.
--
-- Every shim is installed ONLY when the real API is missing, so on a newer
-- Neovim this file does nothing. Required first thing in init.lua.
--
-- Kept deliberately small: each entry is either a pure alias for the 0.8
-- equivalent, or a thin wrapper with the same call shape as the real thing.

local has = function(v) return vim.fn.has("nvim-" .. v) == 1 end

-- 0.10: vim.uv is the new name for vim.loop (same luv object).
vim.uv = vim.uv or vim.loop

-- 0.10: vim.islist is the new name for vim.tbl_islist.
vim.islist = vim.islist or vim.tbl_islist

-- 0.10: vim.hl is the new name for vim.highlight.
vim.hl = vim.hl or vim.highlight

-- 0.10: vim.fs.joinpath
if not vim.fs.joinpath then
  function vim.fs.joinpath(...)
    return (table.concat({ ... }, "/"):gsub("//+", "/"))
  end
end

-- 0.10: vim.fs.root(source, markers). source is a path or a buffer number;
-- markers are tried in priority order, each searched upward from source.
if not vim.fs.root then
  function vim.fs.root(source, marker)
    local path = source
    if type(source) == "number" then
      path = vim.api.nvim_buf_get_name(source)
    end
    if not path or path == "" then
      path = vim.fn.getcwd()
    end
    path = vim.fn.fnamemodify(path, ":p")
    if vim.fn.isdirectory(path) == 0 then
      path = vim.fs.dirname(path)
    end
    local markers = type(marker) == "table" and marker or { marker }
    for _, m in ipairs(markers) do
      local found = vim.fs.find(m, { path = path, upward = true })[1]
      if found then
        return vim.fs.dirname(found)
      end
    end
    return nil
  end
end

-- 0.10: vim.spairs (iterate a table in sorted-key order).
if not vim.spairs then
  function vim.spairs(t)
    local keys = vim.tbl_keys(t)
    table.sort(keys)
    local i = 0
    return function()
      i = i + 1
      local k = keys[i]
      if k ~= nil then
        return k, t[k]
      end
    end
  end
end

-- 0.10: vim.lsp.get_clients (0.8 calls it get_active_clients).
--
-- Also works around a bug in Neovim 0.8.0-0.9.x: get_active_clients({ bufnr = n })
-- crashes ("attempt to index local 'client'") when asked while a server attached
-- to that buffer is still starting. It is replaced here too, since lspconfig and
-- Neovim's own LSP code call it. Same results, but it only walks fully started
-- clients, so the crash can't happen.
if not vim.lsp.get_clients then
  local get_all = vim.lsp.get_active_clients -- unfiltered, it only walks started clients

  local function get_active_clients(filter)
    filter = filter or {}
    local bufnr = filter.bufnr
    if bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end
    local clients = {}
    for _, c in ipairs(get_all()) do
      if (filter.id == nil or c.id == filter.id)
        and (filter.name == nil or c.name == filter.name)
        and (bufnr == nil or vim.lsp.buf_is_attached(bufnr, c.id))
      then
        clients[#clients + 1] = c
      end
    end
    return clients
  end
  vim.lsp.get_active_clients = get_active_clients

  function vim.lsp.get_clients(filter)
    local clients = get_active_clients(filter)
    if filter and filter.method then
      clients = vim.tbl_filter(function(c)
        return c.supports_method(filter.method, { bufnr = filter.bufnr })
      end, clients)
    end
    return clients
  end
end

-- 0.11: vim.diagnostic.jump({ count = n, float = ... }). Unlike goto_next, it
-- does not open a float unless asked to.
if not vim.diagnostic.jump then
  function vim.diagnostic.jump(opts)
    opts = opts or {}
    local count = opts.count or 1
    local step = count > 0 and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
    for i = 1, math.abs(count) do
      step({
        wrap = opts.wrap,
        severity = opts.severity,
        namespace = opts.namespace,
        float = (i == math.abs(count)) and (opts.float or false) or false,
      })
    end
  end
end

-- 0.9: vim.treesitter.query.get / .parse are the new names for
-- get_query / parse_query (same arguments, same results).
do
  local q = vim.treesitter.query
  q.get = q.get or q.get_query
  q.parse = q.parse or q.parse_query
end

-- 0.9: vim.health.start/ok/warn/error/info are the new names for
-- report_start/report_ok/... (plugin :checkhealth pages use the new ones).
do
  local health = vim.health
  if health and not health.start then
    health.start = health.report_start
    health.ok = health.report_ok
    health.warn = health.report_warn
    health.error = health.report_error
    health.info = health.report_info
  end
end

-- 0.10: vim.system(cmd, opts, on_exit). Implemented on jobstart. Supports what
-- this config and its plugins use: cwd, env, clear_env, stdin (string or
-- list), text, timeout, an on_exit callback, and :wait()/:kill() on the result.
if not vim.system then
  function vim.system(cmd, opts, on_exit)
    if type(opts) == "function" then
      on_exit, opts = opts, nil
    end
    opts = opts or {}
    local state = { done = false }
    local out, err = { "" }, { "" }

    local function finish(code, signal)
      local stdout = table.concat(out, "\n")
      local stderr = table.concat(err, "\n")
      if opts.text then
        stdout = stdout:gsub("\r\n", "\n")
        stderr = stderr:gsub("\r\n", "\n")
      end
      state.result = {
        code = code,
        signal = signal or 0,
        stdout = opts.stdout ~= false and stdout or nil,
        stderr = opts.stderr ~= false and stderr or nil,
      }
      state.done = true
      if on_exit then
        on_exit(state.result)
      end
    end

    local ok, job = pcall(vim.fn.jobstart, cmd, {
      cwd = opts.cwd,
      env = opts.env,
      clear_env = opts.clear_env,
      stdout_buffered = true,
      stderr_buffered = true,
      on_stdout = function(_, data) out = data end,
      on_stderr = function(_, data) err = data end,
      on_exit = function(_, code) finish(code) end,
    })
    if not ok or job <= 0 then
      local name = type(cmd) == "table" and cmd[1] or tostring(cmd)
      error(("vim.system: failed to start %s"):format(name))
    end

    if type(opts.stdin) == "string" or type(opts.stdin) == "table" then
      vim.fn.chansend(job, opts.stdin)
    end
    if opts.stdin ~= true then
      vim.fn.chanclose(job, "stdin")
    end

    local obj = { pid = vim.fn.jobpid(job) }
    function obj:wait(timeout)
      local done = vim.wait(timeout or opts.timeout or 1e9, function()
        return state.done
      end, 10)
      if not done then
        vim.fn.jobstop(job)
        vim.wait(1000, function() return state.done end, 10)
        state.result = state.result or { code = 124, signal = 15, stdout = "", stderr = "" }
      end
      return state.result
    end
    function obj:kill() vim.fn.jobstop(job) end
    function obj:write(data)
      if data == nil then vim.fn.chanclose(job, "stdin") else vim.fn.chansend(job, data) end
    end
    function obj:is_closing() return state.done end
    return obj
  end
end

-- 0.9 added title/title_pos to floating windows, 0.10 added footer/footer_pos.
-- Older versions reject those keys outright ("invalid key: title"), which
-- breaks any plugin that sets them (harpoon's menu, devdocs, vim-be-good).
-- Drop just those keys so the window still opens, without its title.
if not has("0.10") then
  local unsupported = { "footer", "footer_pos" }
  if not has("0.9") then
    vim.list_extend(unsupported, { "title", "title_pos" })
  end
  local function clean(config)
    if type(config) ~= "table" then
      return config
    end
    local copy
    for _, key in ipairs(unsupported) do
      if config[key] ~= nil then
        copy = copy or vim.deepcopy(config)
        copy[key] = nil
      end
    end
    return copy or config
  end
  local open_win, set_config = vim.api.nvim_open_win, vim.api.nvim_win_set_config
  vim.api.nvim_open_win = function(buf, enter, config)
    return open_win(buf, enter, clean(config))
  end
  vim.api.nvim_win_set_config = function(win, config)
    return set_config(win, clean(config))
  end
end

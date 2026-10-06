-- Runs the plugin specs in lua/plugins/*.lua without a plugin manager.
--
-- The spec files are the same lazy.nvim-format files as Derrekito/nvim, so
-- they copy across unchanged. Installing is not done here: install-plugins.sh
-- puts every plugin from plugins.lock, at its pinned commit, in
-- ~/.local/share/nvim/site/pack/plugins/start/, where Neovim finds it on its
-- own. All this file does is run each spec's setup, eagerly, in order:
--
--   1. every `init` (before any plugin is configured, as lazy.nvim does)
--   2. `config(plugin, opts)`, or `require(<main>).setup(opts)` when a spec
--      has only `opts`; dependencies first, then by `priority`, then by file
--   3. `keys` entries that carry their own right-hand side (most only name a
--      key whose mapping the config sets; those need nothing here)
--
-- Load triggers (`ft`, `cmd`, `event`, `lazy`) are ignored: everything loads
-- at startup. `build` steps are run by install-plugins.sh. Each spec runs
-- under pcall, so one broken plugin reports an error and the rest still load.
local M = {}

local pack = vim.fn.stdpath("data") .. "/site/pack/plugins"

local function errorf(fmt, ...)
  local msg = fmt:format(...)
  vim.schedule(function() vim.notify(msg, vim.log.levels.ERROR) end)
end

-- "owner/repo" -> repo; an explicit `name` or local `dir` wins.
local function spec_name(spec)
  if spec.name then return spec.name end
  if spec.dir then return vim.fs.basename(spec.dir) end
  local slug = spec[1]
  return type(slug) == "string" and slug:match("[^/]+$") or nil
end

local function spec_id(spec)
  return spec.dir or spec[1] or spec.name
end

local function plugin_dir(spec)
  if spec.dir then return spec.dir end
  local name = spec_name(spec)
  if not name then return nil end
  for _, kind in ipairs({ "start", "opt" }) do
    local d = pack .. "/" .. kind .. "/" .. name
    if vim.uv.fs_stat(d) then return d end
  end
end

-- The module `opts` goes to when there's no `config`: the plugin's lua/
-- module whose name matches the plugin's, as lazy.nvim works it out
-- (render-markdown.nvim -> render-markdown, nvim-autopairs -> nvim-autopairs).
local function norm(s)
  return (s:lower():gsub("^n?vim%-", ""):gsub("%.n?vim$", ""):gsub("[%.%-]lua$", ""):gsub("[^a-z]", ""))
end
local function main_module(spec)
  if spec.main then return spec.main end
  local dir = plugin_dir(spec)
  if not dir or not vim.uv.fs_stat(dir .. "/lua") then return nil end
  local want = norm(spec_name(spec) or "")
  local found
  for entry in vim.fs.dir(dir .. "/lua") do
    local mod = entry:gsub("%.lua$", "")
    if norm(mod) == want then return mod end
    found = found or mod
  end
  return found
end

-- Flatten the spec files into one entry per plugin. Dependencies given as
-- full specs are entries too; repeated entries for one plugin merge.
local function collect()
  local by_id, order = {}, {}
  local function add(spec, file)
    if type(spec) == "string" then spec = { spec } end
    if type(spec) ~= "table" then return end
    -- A list of specs: no plugin of its own, just entries (tables or "owner/repo").
    if type(spec[1]) == "table" or (spec[1] == nil and spec.dir == nil and spec.name == nil) then
      for _, s in ipairs(spec) do add(s, file) end
      return
    end
    if spec.enabled == false or (type(spec.cond) == "function" and not spec.cond()) or spec.cond == false then
      return
    end
    local id = spec_id(spec)
    local entry = by_id[id]
    if not entry then
      entry = { id = id, spec = {}, deps = {}, file = file, rank = #order }
      by_id[id] = entry
      order[#order + 1] = entry
    end
    for k, v in pairs(spec) do
      if k ~= "dependencies" then entry.spec[k] = v end
    end
    for _, dep in ipairs(type(spec.dependencies) == "table" and spec.dependencies
      or (spec.dependencies and { spec.dependencies } or {})) do
      add(dep, file)
      entry.deps[#entry.deps + 1] = spec_id(type(dep) == "string" and { dep } or dep)
    end
  end

  local files = vim.api.nvim_get_runtime_file("lua/plugins/*.lua", true)
  table.sort(files)
  for _, f in ipairs(files) do
    local mod = "plugins." .. vim.fn.fnamemodify(f, ":t:r")
    local ok, spec = pcall(require, mod)
    if ok then
      add(spec, mod)
    else
      errorf("lua/%s.lua failed to load:\n%s", mod:gsub("%.", "/"), spec)
    end
  end
  return by_id, order
end

-- Dependencies before dependents; otherwise higher priority, then file order.
local function sorted(by_id, order)
  table.sort(order, function(a, b)
    local pa, pb = a.spec.priority or 50, b.spec.priority or 50
    if pa ~= pb then return pa > pb end
    return a.rank < b.rank
  end)
  local out, state = {}, {}
  local function visit(e)
    if state[e.id] == "done" then return end
    if state[e.id] == "visiting" then return end -- cycle: keep going
    state[e.id] = "visiting"
    for _, d in ipairs(e.deps) do
      if by_id[d] then visit(by_id[d]) end
    end
    state[e.id] = "done"
    out[#out + 1] = e
  end
  for _, e in ipairs(order) do visit(e) end
  return out
end

local function map_keys(spec)
  local keys = spec.keys
  if type(keys) == "function" then keys = keys() end
  for _, k in ipairs(type(keys) == "table" and keys or {}) do
    if type(k) == "table" and k[2] ~= nil then
      local opts = {}
      for key, v in pairs(k) do
        if type(key) == "string" and key ~= "mode" and key ~= "ft" then opts[key] = v end
      end
      local mode = k.mode or "n"
      if k.ft then
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("UserPluginKeys", { clear = false }),
          pattern = k.ft,
          callback = function(ev)
            vim.keymap.set(mode, k[1], k[2], vim.tbl_extend("force", opts, { buffer = ev.buf }))
          end,
        })
      else
        vim.keymap.set(mode, k[1], k[2], opts)
      end
    end
  end
end

function M.setup()
  local by_id, order = collect()
  local list = sorted(by_id, order)

  -- A spec whose plugin isn't installed (install.sh didn't finish, or
  -- plugins.lock lacks it) is skipped with one clear message, instead of the
  -- "module not found" each of its requires would raise.
  local missing = {}
  list = vim.tbl_filter(function(e)
    if e.spec.dir or plugin_dir(e.spec) then return true end
    table.insert(missing, spec_name(e.spec) or e.id)
    return false
  end, list)
  if #missing > 0 then
    errorf("Not installed, so not set up: %s\nRun ~/rocky9-dotfiles/install.sh (or nvim/install-plugins.sh).",
      table.concat(missing, ", "))
  end

  for _, e in ipairs(list) do
    if type(e.spec.init) == "function" then
      local ok, err = pcall(e.spec.init, { name = spec_name(e.spec), dir = plugin_dir(e.spec) })
      if not ok then errorf("%s: init failed:\n%s", e.id, err) end
    end
  end

  for _, e in ipairs(list) do
    local spec = e.spec
    local plugin = { name = spec_name(spec), dir = plugin_dir(spec) }
    local ok, err = pcall(function()
      local opts = spec.opts
      if type(opts) == "function" then opts = opts(plugin, {}) end
      if type(spec.config) == "function" then
        spec.config(plugin, opts or {})
      elseif spec.config == true or opts ~= nil then
        local main = main_module(spec)
        if not main then error("no lua module to call setup() on") end
        require(main).setup(opts or {})
      end
      map_keys(spec)
    end)
    if not ok then errorf("%s (lua/%s.lua): %s", e.id, e.file:gsub("%.", "/"), err) end
  end
end

return M

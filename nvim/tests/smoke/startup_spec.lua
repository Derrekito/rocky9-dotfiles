-- The real config starts cleanly and every plugin is installed and loadable.
-- Runs under lazy.nvim (Derrekito/nvim) or with plain pinned packages
-- (rocky9-dotfiles, lua/config/plugins.lua); each part checks what applies.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")
local has_lazy = H.has_lazy()
local Config = has_lazy and require("lazy.core.config") or nil

describe("startup", function()
  -- Captured before any test touches state (or lets scheduled work, like
  -- lazy.nvim's VeryLazy event, run).
  local errmsg = vim.v.errmsg
  local messages = vim.fn.execute("messages")
  local loaded_at_startup = {}
  for name, p in pairs(Config and Config.plugins or {}) do
    if p._.loaded then loaded_at_startup[name] = true end
  end

  if has_lazy then it("loads only what the first buffer needs; the rest is lazy", function()
    -- colorscheme; nvim-tree (so `nvim <dir>` opens it); Mason + LSP
    -- setup, which must exist before the first buffer; nvim-cmp, which
    -- cmp-nvim-lsp requires when it loads; treesitter start-up.
    local eager = {
      ["lazy.nvim"] = true, neovim = true, ["nvim-tree.lua"] = true, ["nvim-web-devicons"] = true,
      ["mason.nvim"] = true, ["mason-lspconfig.nvim"] = true, ["nvim-lspconfig"] = true,
      ["cmp-nvim-lsp"] = true, ["nvim-cmp"] = true, ["cmp-buffer"] = true, ["cmp-path"] = true,
      ["cmp-cmdline"] = true, LuaSnip = true, cmp_luasnip = true, ["friendly-snippets"] = true,
      ["tree-sitter-manager.nvim"] = true,
      ["snacks.nvim"] = true, -- image rendering hooks FileType before the first buffer
      ["plenary.nvim"] = true, -- the test harness itself requires it
    }
    local unexpected = {}
    for name in pairs(loaded_at_startup) do
      if not eager[name] then table.insert(unexpected, name) end
    end
    table.sort(unexpected)
    assert(#unexpected == 0, "loaded at startup but should be lazy: " .. table.concat(unexpected, ", "))
  end) end

  if has_lazy then it("draws the statusline before fugitive loads, and the branch after", function()
    assert.is_nil(loaded_at_startup.fugitive)
    assert.has_no.errors(function() vim.api.nvim_eval_statusline(vim.o.statusline, {}) end)
    -- lazy.nvim fires VeryLazy after UIEnter, which a headless nvim never
    -- gets; send it the way attaching a UI would.
    vim.api.nvim_exec_autocmds("UIEnter", {})
    vim.wait(2000, function() return Config.plugins.fugitive._.loaded ~= nil end)
    assert.is_truthy(Config.plugins.fugitive._.loaded, "VeryLazy never loaded fugitive")
    assert.are.equal(1, vim.fn.exists("*FugitiveStatusline"))
  end) end

  if not has_lazy then it("draws the statusline with the git branch", function()
    assert.has_no.errors(function() vim.api.nvim_eval_statusline(vim.o.statusline, {}) end)
    assert.are.equal(1, vim.fn.exists("*FugitiveStatusline"))
  end) end

  it("leaves no error in v:errmsg", function()
    assert.are.equal("", errmsg)
  end)

  it("prints no errors or warnings", function()
    -- The package loader reports a failing spec through vim.schedule.
    if not has_lazy then
      vim.wait(200)
      messages = messages .. "\n" .. vim.fn.execute("messages")
    end
    for _, line in ipairs(vim.split(messages, "\n")) do
      assert(not line:match("E%d+:") and not line:lower():match("error") and not line:lower():match("deprecat"),
        "startup message: " .. line)
    end
  end)

  it("is running Neovim 0.11+ (vim.lsp.config)", function()
    assert.are.equal(1, vim.fn.has("nvim-0.11"))
  end)

  it("uses rose-pine with our overrides", function()
    assert.are.equal("rose-pine", vim.g.colors_name)
    local pine = tonumber(require("rose-pine-moon").palette.pine:sub(2), 16)
    assert.are.equal(pine, vim.api.nvim_get_hl(0, { name = "@type", link = false }).fg)
  end)

  it("keeps options set after plugins load", function()
    assert.is_true(vim.o.hlsearch)
    assert.are.equal(999, vim.o.scrolloff)
    assert.is_true(vim.o.termguicolors)
    assert.are.equal("80", vim.o.colorcolumn)
  end)

  it("disables netrw in favor of nvim-tree", function()
    assert.are.equal(1, vim.g.loaded_netrwPlugin)
    assert.are.equal(0, vim.fn.exists(":Explore"))
  end)
end)

if not has_lazy then
  describe("plugins (pinned packages)", function()
    local pack = vim.fn.stdpath("data") .. "/site/pack/plugins"
    local lock = {}
    for line in io.lines(H.root .. "/plugins.lock") do
      local name, _, _, kind = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
      if name and not name:match("^#") then lock[name] = kind end
    end

    for name, kind in pairs(lock) do
      it(name .. " is installed", function()
        assert(vim.uv.fs_stat(pack .. "/" .. kind .. "/" .. name), name .. " missing; run install-plugins.sh")
      end)
    end

    it("nothing outside plugins.lock is in start/ (it would load)", function()
      local extra = {}
      for entry in vim.fs.dir(pack .. "/start") do
        if not lock[entry] then table.insert(extra, entry) end
      end
      assert(#extra == 0, "not in plugins.lock: " .. table.concat(extra, ", "))
    end)

    it("every spec in lua/plugins names a pinned plugin", function()
      local missing = {}
      local function check(spec)
        if type(spec) == "string" then spec = { spec } end
        if type(spec) ~= "table" then return end
        if type(spec[1]) == "table" or (spec[1] == nil and not spec.dir and not spec.name) then
          for _, s in ipairs(spec) do check(s) end
          return
        end
        if not spec.dir then
          local name = spec.name or spec[1]:match("[^/]+$")
          if not lock[name] then table.insert(missing, name) end
        end
        for _, d in ipairs(type(spec.dependencies) == "table" and spec.dependencies or {}) do check(d) end
      end
      for _, f in ipairs(vim.fn.glob(H.root .. "/lua/plugins/*.lua", false, true)) do
        check(dofile(f))
      end
      assert(#missing == 0, "specified but not in plugins.lock: " .. table.concat(missing, ", "))
    end)
  end)
  return
end

describe("plugins", function()
  local plugins = vim.tbl_values(Config.plugins)
  table.sort(plugins, function(a, b) return a.name < b.name end)

  for _, p in ipairs(plugins) do
    it(p.name .. " is installed", function()
      assert(p._.installed, p.name .. " missing; run :Lazy install")
    end)
  end

  for _, p in ipairs(plugins) do
    if not p.lazy then
      it(p.name .. " loaded (lazy = false)", function()
        assert(p._.loaded, p.name .. " should be loaded (lazy = false)")
      end)
    end
  end

  -- Load each lazy plugin on demand, the way its trigger would.
  for _, p in ipairs(plugins) do
    if p.lazy then
      it(p.name .. " loads on demand without errors", function()
        H.no_errors(function()
          require("lazy").load({ plugins = { p.name } })
        end, 200)
        assert(Config.plugins[p.name]._.loaded, p.name .. " did not load")
      end)
    end
  end

  it("every plugin in lazy-lock.json is still specified", function()
    local lock = vim.json.decode(table.concat(vim.fn.readfile(H.root .. "/lazy-lock.json"), "\n"))
    local stale = {}
    for name in pairs(lock) do
      if not Config.plugins[name] and not Config.spec.disabled[name] then
        table.insert(stale, name)
      end
    end
    assert(#stale == 0, "stale lockfile entries (run :Lazy clean): " .. table.concat(stale, ", "))
  end)

  it("every specified plugin is pinned in lazy-lock.json", function()
    local lock = vim.json.decode(table.concat(vim.fn.readfile(H.root .. "/lazy-lock.json"), "\n"))
    local unpinned = {}
    for name, p in pairs(Config.plugins) do
      if not lock[name] and not p.dir:find(H.root, 1, true) and not p.dev then
        table.insert(unpinned, name)
      end
    end
    assert(#unpinned == 0, "not in lazy-lock.json: " .. table.concat(unpinned, ", "))
  end)
end)

-- Resolved LSP configuration, plus one real end-to-end attach with clangd.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

describe("LSP config", function()
  local servers = { "clangd", "rust_analyzer", "bashls", "lua_ls", "marksman", "pylsp", "jsonls", "texlab", "cmake", "harper_ls" }
  for _, s in ipairs(servers) do
    it(s .. " is enabled", function()
      assert.is_true(vim.lsp.is_enabled(s))
    end)
  end

  it("harper_ls only checks prose, not code comments", function()
    assert.are.same({ "markdown", "text", "gitcommit" }, vim.lsp.config.harper_ls.filetypes)
  end)

  it("no stylua language server (conform runs stylua)", function()
    assert.is_false(vim.lsp.is_enabled("stylua"))
  end)

  it("clangd: one cmd, no obsolete flags, cmp capabilities, no semantic tokens", function()
    local c = vim.lsp.config.clangd
    assert.are.equal("clangd", c.cmd[1])
    assert.is_true(vim.tbl_contains(c.cmd, "--background-index"))
    assert.is_true(vim.tbl_contains(c.cmd, "--clang-tidy"))
    assert.is_false(vim.tbl_contains(c.cmd, "--suggest-missing-includes"))
    assert.is_true(c.capabilities.textDocument.completion.completionItem.snippetSupport)
    assert.are.same({ "compile_commands.json", ".clangd", "compile_flags.txt", ".git" }, c.root_markers)
    local client = { server_capabilities = { semanticTokensProvider = {} } }
    c.on_attach(client, 0)
    assert.is_nil(client.server_capabilities.semanticTokensProvider)
  end)

  it("lua_ls: vim global known, config dir as root for config files", function()
    local c = vim.lsp.config.lua_ls
    assert.is_true(vim.tbl_contains(c.settings.Lua.diagnostics.globals, "vim"))
    vim.cmd("edit " .. vim.fn.stdpath("config") .. "/lua/config/options.lua")
    local root
    c.root_dir(0, function(r) root = r end)
    assert.are.equal(vim.fn.stdpath("config"), root)
    vim.cmd("bwipeout")
  end)

  describe("marksman root_dir never scans $HOME", function()
    local function root_for(path)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(buf, path)
      local root, called = nil, false
      vim.lsp.config.marksman.root_dir(buf, function(r) called, root = true, r end)
      vim.api.nvim_buf_delete(buf, { force = true })
      return called, root
    end
    local home = vim.uv.os_homedir()

    it("uses the project root when there is one", function()
      local d = H.tmpdir()
      vim.fn.mkdir(d .. "/.git", "p")
      vim.fn.mkdir(d .. "/sub", "p")
      local _, root = root_for(d .. "/sub/a.md")
      assert.are.equal(d, root)
    end)

    it("falls back to the file's own directory", function()
      local d = H.tmpdir()
      local _, root = root_for(d .. "/a.md")
      assert.are.equal(d, root)
    end)

    it("does not start at all for a note directly in $HOME", function()
      local called, root = root_for(home .. "/__smoke__.md")
      assert(not called or root ~= home, "marksman would index all of $HOME")
    end)
  end)
end)

describe("lua_ls end-to-end", function()
  if vim.fn.executable("lua-language-server") == 0 then
    pending("lua-language-server not installed")
    return
  end

  it("knows the Neovim API (lazydev): vim is typed, signatures are checked", function()
    local d = H.tmpdir()
    vim.fn.mkdir(d .. "/.git", "p")
    local path = H.write(d, "probe.lua", {
      "local name = vim.api.nvim_buf_get_name(0, 1)", -- one argument too many
      "local y = not_a_global",
      "return name, y",
    })
    vim.cmd("edit " .. path)
    local function diags()
      return vim.tbl_map(function(x) return x.message end, vim.diagnostic.get(0))
    end
    local found = vim.wait(60000, function()
      for _, m in ipairs(diags()) do
        if m:find("maximum of 1 argument", 1, true) then return true end
      end
      return false
    end, 250)
    local all = table.concat(diags(), "\n")
    assert(found, "lua_ls doesn't know nvim_buf_get_name's signature; diagnostics:\n" .. all)
    assert.is_truthy(all:find("not_a_global", 1, true), all)
    assert.is_nil(all:find("Undefined global `vim`", 1, true), all)
    for _, c in ipairs(vim.lsp.get_clients()) do c:stop(true) end
    vim.cmd("bwipeout!")
  end)
end)

describe("clangd end-to-end", function()
  if vim.fn.executable(vim.lsp.config.clangd.cmd[1]) == 0 then
    pending("clangd not on PATH")
    return
  end

  local d = H.tmpdir()
  H.write(d, "compile_flags.txt", { "-std=c++20" })
  local path = H.write(d, "main.cpp", { "int add(int a, int b) { return a + b; }", "int main() { return add(1, 2); }" })

  local function clangd_client()
    return vim.lsp.get_clients({ bufnr = 0, name = "clangd" })[1]
  end

  it("attaches with the project root and our keymaps", function()
    vim.cmd("edit " .. path)
    assert(vim.wait(15000, function() return clangd_client() ~= nil end, 100), "clangd never attached")
    local c = clangd_client()
    assert.are.equal(d, c.root_dir)
    assert.is_nil(c.server_capabilities.semanticTokensProvider)
    assert.is_true(c.__compat_supports_method)
    for _, lhs in ipairs({ "K", "gd", "gr", "<leader>rn", "<leader>ca", "<leader>ds" }) do
      assert.are.equal(1, H.map("n", lhs).buffer, lhs)
    end
    assert.are.equal(0, H.map("n", "<leader>k").buffer, "<leader>k should stay lnext")
  end)

  it(":LspRestart brings clangd back, shut down cleanly", function()
    local old = clangd_client().id
    local seen, stop = H.capture_notify()
    vim.cmd("messages clear")
    vim.cmd("LspRestart")
    assert(vim.wait(15000, function()
      local c = clangd_client()
      return c ~= nil and c.id ~= old
    end, 100), "clangd did not come back")
    vim.wait(500)
    stop()
    local all = vim.fn.execute("messages") .. table.concat(vim.tbl_map(function(n) return n.msg end, seen), "\n")
    assert.is_nil(all:find("quit with exit code"), all)
  end)

  it("restarts clangd when the project's .clangd changes", function()
    local old = clangd_client().id
    H.write(d, ".clangd", { "Diagnostics:", "  UnusedIncludes: None" })
    assert(vim.wait(15000, function()
      local c = clangd_client()
      return c ~= nil and c.id ~= old
    end, 100), "no restart after writing .clangd")
  end)

  it("stops cleanly", function()
    for _, c in ipairs(vim.lsp.get_clients()) do c:stop(true) end
    vim.wait(3000, function() return #vim.lsp.get_clients() == 0 end)
  end)
end)

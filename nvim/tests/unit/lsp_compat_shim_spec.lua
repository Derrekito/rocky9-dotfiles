local shim = require("lsp-compat-shim")

-- A stand-in for vim.lsp.Client: the real method on the metatable, and an
-- instance field that (like 0.12's dot-form wrapper) is something else.
local function fake_client()
  local calls = {}
  local mt = {}
  mt.__index = mt
  function mt.supports_method(self, method, opts)
    table.insert(calls, { self = self, method = method, opts = opts })
    return method == "yes"
  end
  local client = setmetatable({}, mt)
  client.supports_method = function() error("deprecated dot form called") end
  return client, calls
end

describe("lsp-compat-shim rewrap", function()
  it("makes the dot form forward to the real method", function()
    local c, calls = fake_client()
    shim._rewrap(c)
    assert.is_true(c.supports_method("yes"))
    assert.is_false(c.supports_method("no", { bufnr = 1 }))
    assert.are.equal(c, calls[1].self)
    assert.are.same({ bufnr = 1 }, calls[2].opts)
  end)

  it("keeps the colon form working", function()
    local c, calls = fake_client()
    shim._rewrap(c)
    assert.is_true(c:supports_method("yes"))
    assert.are.equal(c, calls[1].self)
    assert.are.equal("yes", calls[1].method)
  end)

  it("is idempotent", function()
    local c = fake_client()
    shim._rewrap(c)
    local first = c.supports_method
    shim._rewrap(c)
    assert.are.equal(first, c.supports_method)
  end)

  it("ignores nil and clients without a real method", function()
    shim._rewrap(nil)
    local c = setmetatable({}, {})
    shim._rewrap(c)
    assert.is_nil(c.__compat_supports_method)
  end)

  it("setup registers a single LspAttach handler however often it runs", function()
    shim.setup()
    shim.setup()
    local cmds = vim.api.nvim_get_autocmds({ group = "LspCompatShim", event = "LspAttach" })
    assert.are.equal(1, #cmds)
  end)
end)

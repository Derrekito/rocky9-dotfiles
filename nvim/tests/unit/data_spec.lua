-- Static data modules: the Rose Pine palette and the cheatsheet.
describe("rose-pine-moon palette", function()
  local rp = require("rose-pine-moon")

  it("has 15 valid hex colors", function()
    local n = 0
    for name, hex in pairs(rp.palette) do
      n = n + 1
      assert(hex:match("^#%x%x%x%x%x%x$"), name .. " = " .. hex)
    end
    assert.are.equal(15, n)
  end)

  it("defines every role in terms of a palette color", function()
    local values = {}
    for _, hex in pairs(rp.palette) do values[hex] = true end
    local function check(t, path)
      for k, v in pairs(t) do
        if type(v) == "table" then
          check(v, path .. "." .. k)
        else
          assert(values[v], path .. "." .. k .. " is off-palette: " .. v)
        end
      end
    end
    check(rp.roles, "roles")
    for i = 1, 6 do assert.is_not_nil(rp.roles.headings["h" .. i]) end
  end)
end)

describe("cheatsheet data", function()
  local data = require("cheatsheet.data")

  it("has sections with a unique category and string items", function()
    local seen = {}
    assert.is_true(#data.sections > 0)
    for _, s in ipairs(data.sections) do
      assert.are.equal("string", type(s.category))
      assert(not seen[s.category], "duplicate category " .. s.category)
      seen[s.category] = true
      assert.is_true(#s.items > 0, s.category .. " is empty")
      for _, item in ipairs(s.items) do
        assert.are.equal("string", type(item))
      end
    end
  end)

  it("never names a key that isn't used anymore", function()
    local gone = { "v: <leader>d ", "n: ]d ", "n: <leader>[d", "n: <leader>ds         → Step over", "n: <Space> " }
    for _, s in ipairs(data.sections) do
      for _, item in ipairs(s.items) do
        for _, g in ipairs(gone) do
          assert(not item:find(g, 1, true), s.category .. ": stale entry " .. item)
        end
      end
    end
  end)
end)

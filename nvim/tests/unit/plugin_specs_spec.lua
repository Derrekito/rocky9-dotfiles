-- Every lua/plugins/*.lua returns a well-formed lazy.nvim spec. Loaded with
-- dofile, so nothing here needs the plugins themselves installed.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local files = vim.fn.glob(root .. "/lua/plugins/*.lua", false, true)

local function is_single(spec)
  return type(spec[1]) == "string" or spec.dir ~= nil or spec.url ~= nil
end

local function each_spec(spec, fn)
  if type(spec) == "string" then
    return fn({ spec })
  end
  if is_single(spec) then
    fn(spec)
    for _, dep in ipairs(spec.dependencies or {}) do each_spec(dep, fn) end
  else
    for _, s in ipairs(spec) do each_spec(s, fn) end
  end
end

local function str_or_list(v)
  if type(v) == "string" then return { v } end
  return v
end

local allowed = {
  [1] = true, dir = true, url = true, name = true, dev = true, lazy = true, enabled = true,
  cond = true, dependencies = true, init = true, opts = true, config = true, main = true,
  build = true, branch = true, tag = true, commit = true, version = true, pin = true,
  submodules = true, event = true, cmd = true, ft = true, keys = true, module = true,
  priority = true, optional = true,
}

describe("plugin specs", function()
  it("finds the spec files", function()
    assert.is_true(#files > 20)
  end)

  local names = {}
  for _, file in ipairs(files) do
    local short = vim.fn.fnamemodify(file, ":t")
    describe(short, function()
      local ok, spec = pcall(dofile, file)

      it("loads and returns a table", function()
        assert(ok, spec)
        assert.are.equal("table", type(spec))
      end)
      if not ok or type(spec) ~= "table" then return end

      it("has only known lazy.nvim fields with the right types", function()
        each_spec(spec, function(s)
          local id = s[1] or s.dir
          for k in pairs(s) do
            assert(allowed[k], ("%s: unknown field %q"):format(id, tostring(k)))
          end
          if s[1] then
            assert(s[1]:match("^[%w_.-]+/[%w_.-]+$"), "bad repo name " .. s[1])
          end
          if s.dir then
            assert.are.equal(1, vim.fn.isdirectory(s.dir), "dir missing: " .. s.dir)
          end
          for _, f in ipairs({ "config", "init", "opts", "build" }) do
            local t = type(s[f])
            if s[f] ~= nil then
              assert(t == "function" or t == "table" or t == "boolean" or t == "string",
                ("%s: %s is a %s"):format(id, f, t))
            end
          end
          for _, ev in ipairs(str_or_list(s.event) or {}) do
            local name = ev:match("^(%S+)")
            assert(name == "VeryLazy" or name == "User" or vim.fn.exists("##" .. name) == 1,
              ("%s: unknown event %s"):format(id, ev))
          end
          for _, k in ipairs(s.keys or {}) do
            local lhs = type(k) == "string" and k or k[1]
            assert.are.equal("string", type(lhs))
          end
        end)
      end)

      it("does not set up anything at require time", function()
        -- Specs must be pure data: everything happens in config/init.
        each_spec(spec, function(s)
          if type(s.config) == "table" then
            error((s[1] or s.dir) .. ": config should be a function or true")
          end
        end)
      end)

      each_spec(spec, function(s)
        if s[1] and (s.config or s.opts) then
          table.insert(names, { name = s[1], file = short })
        end
      end)
    end)
  end

  it("configures each plugin in only one file", function()
    local seen = {}
    for _, n in ipairs(names) do
      assert(not seen[n.name] or seen[n.name] == n.file,
        ("%s configured in both %s and %s"):format(n.name, tostring(seen[n.name]), n.file))
      seen[n.name] = n.file
    end
  end)
end)

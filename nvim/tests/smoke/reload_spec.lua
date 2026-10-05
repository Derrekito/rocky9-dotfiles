-- Saving a config file reloads options/keymaps/autocmds in the running
-- editor. Simulated with the autocmd event, so no real file is rewritten.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

local function snapshot()
  local counts = {}
  for _, a in ipairs(vim.api.nvim_get_autocmds({})) do
    local key = (a.group_name or "<none>") .. "/" .. a.event
    counts[key] = (counts[key] or 0) + 1
  end
  return counts
end

describe("config reload on save", function()
  it("doesn't pile up autocmds, however many times you save", function()
    vim.cmd("edit " .. H.write(H.tmpdir(), "x.cpp", { "" }))
    local cfg = vim.fn.stdpath("config") .. "/lua/config/keymaps.lua"
    vim.api.nvim_exec_autocmds("BufWritePost", { pattern = cfg })
    local before = snapshot()
    for _ = 1, 4 do
      H.no_errors(function() vim.api.nvim_exec_autocmds("BufWritePost", { pattern = cfg }) end)
    end
    local after = snapshot()
    local grew = {}
    for k, n in pairs(after) do
      -- nvim.* groups are Neovim's own, created on first use. A group going
      -- from none to one is a plugin finishing its own deferred setup during
      -- the loop (lazydev does, when it loads at startup); piling up means a
      -- second copy of something that was already there.
      local was = before[k] or 0
      if n > was and was > 0 and not k:match("^nvim%.") then table.insert(grew, ("%s: %d -> %d"):format(k, was, n)) end
    end
    table.sort(grew)
    assert(#grew == 0, "autocmds grew:\n" .. table.concat(grew, "\n"))
  end)

  it("keeps the options and keymaps", function()
    assert.is_true(vim.o.hlsearch)
    assert.is_not_nil(H.map("n", "<leader>D"))
    assert.is_not_nil(H.map("n", "<leader><leader>"))
  end)
end)

-- config.options in isolation (no plugins).
local function count(group)
  local ok, cmds = pcall(vim.api.nvim_get_autocmds, { group = group })
  return ok and #cmds or 0
end

local function reload_all()
  for _, m in ipairs({ "config.options", "config.keymaps", "config.autocmds" }) do
    package.loaded[m] = nil
    require(m)
  end
end

describe("config.options", function()
  reload_all()

  it("sets the intended editor options", function()
    assert.is_true(vim.o.hlsearch)
    assert.is_true(vim.o.incsearch)
    assert.is_false(vim.o.wrap)
    assert.is_true(vim.o.linebreak)
    assert.is_true(vim.o.breakindent)
    assert.are.equal(999, vim.o.scrolloff)
    assert.are.equal(2, vim.o.shiftwidth)
    assert.is_true(vim.o.expandtab)
    assert.is_true(vim.o.undofile)
    assert.is_false(vim.o.swapfile)
    assert.are.equal("80", vim.o.colorcolumn)
    assert.are.equal(2, vim.o.conceallevel)
    assert.is_true(vim.o.number and vim.o.relativenumber)
    assert.are.equal(1, vim.fn.isdirectory(vim.o.undodir))
  end)

  it("puts every autocmd in its group", function()
    assert.is_true(count("UserOptions") > 0)
  end)

  it("reloading does not stack autocmds", function()
    local groups = { "UserOptions", "UserKeymaps", "UserAutoCommands", "HighlightYank" }
    local before = {}
    for _, g in ipairs(groups) do before[g] = count(g) end
    reload_all()
    reload_all()
    for _, g in ipairs(groups) do
      assert.are.equal(before[g], count(g), g)
    end
  end)

  it("the save-a-config-file reload keeps exactly one reload autocmd", function()
    local cfg = vim.fn.stdpath("config") .. "/lua/config/options.lua"
    local function reload_cmds()
      return #vim.api.nvim_get_autocmds({ group = "UserOptions", event = "BufWritePost" })
    end
    assert.are.equal(1, reload_cmds())
    for _ = 1, 3 do
      vim.api.nvim_exec_autocmds("BufWritePost", { pattern = cfg })
    end
    assert.are.equal(1, reload_cmds())
  end)

  it("the reload autocmd ignores files outside the config", function()
    package.loaded["config.options"] = true -- sentinel: a reload would replace it
    vim.api.nvim_exec_autocmds("BufWritePost", { pattern = "/tmp/elsewhere.lua" })
    assert.is_true(package.loaded["config.options"])
    package.loaded["config.options"] = nil
    require("config.options")
  end)

  it("detects *.latex as a pandoc template", function()
    assert.are.equal("pandoc-latex", vim.filetype.match({ filename = "default.latex" }))
    assert.are_not.equal("pandoc-latex", vim.filetype.match({ filename = "paper.tex" }))
  end)

  it("uses real tabs in Makefiles", function()
    vim.cmd("enew")
    vim.bo.filetype = "make"
    assert.is_false(vim.bo.expandtab)
    assert.are.equal(8, vim.bo.tabstop)
    vim.cmd("bwipeout!")
  end)

  it("the checktime autocmd is a no-op in the command-line window", function()
    local cb = vim.api.nvim_get_autocmds({ group = "UserOptions", event = "CursorHold" })[1].callback
    local orig = vim.fn.getcmdwintype
    vim.fn.getcmdwintype = function() return ":" end
    local ok, err = pcall(cb)
    vim.fn.getcmdwintype = orig
    assert(ok, err)
  end)
end)

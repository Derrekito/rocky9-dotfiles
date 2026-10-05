local mg = require("config.telescope.multigrep")

describe("multigrep.build_command", function()
  local tail = { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" }

  it("returns nil for an empty prompt", function()
    assert.is_nil(mg.build_command(""))
    assert.is_nil(mg.build_command(nil))
  end)

  it("searches the pattern", function()
    assert.are.same(vim.list_extend({ "rg", "-e", "TODO" }, tail), mg.build_command("TODO"))
  end)

  it("treats text after two spaces as a glob", function()
    assert.are.same(vim.list_extend({ "rg", "-e", "TODO", "-g", "*.lua" }, tail), mg.build_command("TODO  *.lua"))
  end)

  it("keeps single spaces inside the pattern", function()
    local cmd = mg.build_command("foo bar")
    assert.are.equal("foo bar", cmd[3])
    assert.are.equal("--color=never", cmd[4])
  end)

  it("loads without telescope (requires are deferred)", function()
    assert.is_nil(package.loaded["telescope.pickers"])
  end)
end)

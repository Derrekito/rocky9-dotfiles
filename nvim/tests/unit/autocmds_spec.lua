local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

describe("config.autocmds", function()
  package.loaded["config.autocmds"] = nil
  require("config.autocmds")
  after_each(function() vim.cmd("silent! %bwipeout!") end)

  it("configures diagnostics", function()
    local c = vim.diagnostic.config()
    assert.is_false(c.virtual_text)
    assert.is_true(c.severity_sort)
    assert.are.equal("✘", c.signs.text[vim.diagnostic.severity.ERROR])
  end)

  it("strips trailing whitespace on write, keeping cursor and last search", function()
    local path = H.write(H.tmpdir(), "a.txt", {})
    vim.cmd("silent edit " .. path)
    vim.bo.undofile = false
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one   ", "two\t", "three" })
    vim.fn.setreg("/", "three")
    vim.api.nvim_win_set_cursor(0, { 2, 1 })
    vim.cmd("silent write")
    assert.are.same({ "one", "two", "three" }, vim.fn.readfile(path))
    assert.are.same({ 2, 1 }, vim.api.nvim_win_get_cursor(0))
    assert.are.equal("three", vim.fn.getreg("/"))
  end)

  it("leaves non-modifiable buffers alone without erroring", function()
    local cb = vim.api.nvim_get_autocmds({ group = "UserAutoCommands", event = "BufWritePre" })[1].callback
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x  " })
    vim.bo.modifiable = false
    H.no_errors(cb)
    assert.are.same({ "x  " }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it("highlights yanks without erroring", function()
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abc" })
    H.no_errors(function() vim.cmd("normal! yy") end)
  end)

  it("sets buffer-local LSP maps on LspAttach", function()
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_exec_autocmds("LspAttach", { buffer = buf, data = { client_id = 0 } })
    for _, e in ipairs({
      { "n", "gr" }, { "n", "gd" }, { "n", "K" }, { "n", "<leader>rn" }, { "n", "<leader>ca" },
      { "n", "<leader>ws" }, { "i", "<C-h>" }, { "n", "<leader>ds" }, { "n", "<leader>dS" },
    }) do
      local m = H.map(e[1], e[2])
      assert(m and m.buffer == 1, ("missing buffer-local %s %s"):format(e[1], e[2]))
    end
  end)

  it("leaves normal-mode <leader>k to the global location-list map", function()
    vim.cmd("enew")
    vim.api.nvim_exec_autocmds("LspAttach", { buffer = 0, data = { client_id = 0 } })
    local m = H.map("n", "<leader>k")
    assert(not m or m.buffer == 0, "LspAttach shadows <leader>k")
  end)

  it("defines R() for reloading modules", function()
    assert.are.equal("function", type(R))
  end)
end)

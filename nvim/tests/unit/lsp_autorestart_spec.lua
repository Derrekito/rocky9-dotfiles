local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")
local ar = require("lsp-autorestart")

describe("lsp-autorestart reload_for_lsp", function()
  after_each(function() vim.cmd("silent! %bwipeout!") end)

  it("reloads a clean file buffer from disk", function()
    local path = H.write(H.tmpdir(), "a.txt", { "old" })
    vim.cmd("silent edit " .. path)
    vim.fn.writefile({ "new" }, path)
    ar.reload_for_lsp()
    assert.are.same({ "new" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it("skips (and says so) when the buffer is modified", function()
    local path = H.write(H.tmpdir(), "a.txt", { "old" })
    vim.cmd("silent edit " .. path)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "dirty" })
    local seen, stop = H.capture_notify()
    ar.reload_for_lsp()
    stop()
    assert.are.same({ "dirty" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.are.equal(1, #seen)
  end)

  it("does not error in a buffer with no file", function()
    vim.cmd("enew")
    vim.v.errmsg = ""
    assert.has_no.errors(ar.reload_for_lsp)
    assert.are.equal("", vim.v.errmsg)
  end)

  it("does not error in a nofile buffer", function()
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.api.nvim_buf_set_name(0, "scratch-thing")
    assert.has_no.errors(ar.reload_for_lsp)
  end)
end)

describe("lsp-autorestart .clangd watcher", function()
  it("restarts once for a burst of .clangd events", function()
    local orig = ar.restart
    local n = 0
    ar.restart = function() n = n + 1 end
    ar.on_root_event(".clangd")
    ar.on_root_event(".clangd")
    ar.on_root_event(".clangd")
    vim.wait(1000, function() return n > 0 end)
    vim.wait(300)
    ar.restart = orig
    assert.are.equal(1, n)
  end)

  it("ignores other files in the root", function()
    local orig = ar.restart
    local n = 0
    ar.restart = function() n = n + 1 end
    ar.on_root_event("main.cpp")
    ar.on_root_event(nil)
    vim.wait(400)
    ar.restart = orig
    assert.are.equal(0, n)
  end)

  it("defines :LspRestart", function()
    assert.is_not_nil(vim.api.nvim_get_commands({}).LspRestart)
  end)
end)

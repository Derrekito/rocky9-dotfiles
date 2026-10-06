-- Commands exist, and UIs open and close cleanly.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

local dir = H.tmpdir()
local function open_file(name, lines)
  vim.cmd("edit " .. H.write(dir, name, lines or { "int main() { return 0; }" }))
end

describe("commands", function()
  local commands = {
    "LspRestart", "Cheatsheet", "FormatToggle", "FormatStatus", "ConformInfo",
    "TypeAnim", "TypeAnimToggle", "Trouble", "ZenMode", "AerialToggle", "NvimTreeToggle",
    "Telescope", "Git", "Mason", "Devdocs", "VimBeGood",
  }
  if pcall(require, "lazy") then table.insert(commands, "Lazy") end
  local have = vim.api.nvim_get_commands({})
  for _, c in ipairs(commands) do
    it(":" .. c .. " exists", function()
      assert(have[c] or vim.fn.exists(":" .. c) == 2, ":" .. c .. " is not defined")
    end)
  end

  -- Defined once a buffer of the right kind is open.
  for _, c in ipairs({ { "ui.cpp", "ClangFormatIndentSync" }, { "ui.cpp", "Lint" }, { "t.md", "TableModeToggle" } }) do
    it(":" .. c[2] .. " exists after opening " .. c[1], function()
      open_file(c[1])
      assert.are.equal(2, vim.fn.exists(":" .. c[2]))
      H.reset()
    end)
  end
end)

describe("UIs", function()
  before_each(function() open_file("ui.cpp") end)
  after_each(H.reset)

  it(":FormatToggle works before conform has loaded and toggles back", function()
    H.no_errors(function() vim.cmd("FormatToggle") end)
    assert.is_true(vim.g.disable_autoformat)
    H.no_errors(function() vim.cmd("FormatToggle") end)
    assert.is_false(vim.g.disable_autoformat)
  end)

  it(":FormatStatus lists the buffer's formatters by name", function()
    local seen, stop = H.capture_notify()
    H.no_errors(function() vim.cmd("FormatStatus") end)
    stop()
    local msg = seen[#seen].msg
    assert.is_truthy(msg:find("clang_format", 1, true), msg)
    assert.is_nil(msg:find("nil", 1, true), msg)
  end)

  it(":Trouble diagnostics toggles open and closed", function()
    vim.diagnostic.set(vim.api.nvim_create_namespace("smoke"), 0, {
      { lnum = 0, col = 0, message = "smoke test", severity = vim.diagnostic.severity.ERROR },
    })
    H.no_errors(function() vim.cmd("Trouble diagnostics toggle") end, 500)
    assert.is_true(require("trouble").is_open("diagnostics"))
    H.no_errors(function() require("trouble").next({ skip_groups = true, jump = true }) end, 100)
    H.no_errors(function() require("trouble").prev({ skip_groups = true, jump = true }) end, 100)
    H.no_errors(function() vim.cmd("Trouble diagnostics toggle") end, 200)
    assert.is_false(require("trouble").is_open("diagnostics"))
  end)

  it(":ZenMode opens and closes, restoring colorcolumn and wrap", function()
    vim.wo.wrap = false
    H.no_errors(function() vim.cmd("ZenMode") end, 200)
    assert.is_true(vim.wo.wrap)
    assert.are.equal("", vim.wo.colorcolumn)
    H.no_errors(function() vim.cmd("ZenMode") end, 200)
    assert.is_false(vim.wo.wrap)
    assert.are.equal("80", vim.wo.colorcolumn)
  end)

  it(":NvimTreeToggle", function()
    H.no_errors(function() vim.cmd("NvimTreeToggle") end, 200)
    assert.is_true(require("nvim-tree.api").tree.is_visible())
    H.no_errors(function() vim.cmd("NvimTreeToggle") end, 200)
    assert.is_false(require("nvim-tree.api").tree.is_visible())
  end)

  it("editing a directory opens nvim-tree", function()
    H.no_errors(function() vim.cmd("edit " .. dir) end, 300)
    assert.is_true(require("nvim-tree.api").tree.is_visible())
    vim.cmd("NvimTreeClose")
  end)

  it(":AerialToggle!", function()
    H.no_errors(function() vim.cmd("AerialToggle!") end, 300)
    H.no_errors(function() vim.cmd("AerialToggle!") end, 100)
  end)

  it(":ClangFormatIndentSync", function()
    H.no_errors(function() vim.cmd("ClangFormatIndentSync") end)
  end)

  it(":LspRestart with no clients", function()
    H.no_errors(function() vim.cmd("LspRestart") end, 700)
  end)

  it(":Lint", function()
    H.no_errors(function() vim.cmd("Lint") end, 500)
  end)

  it("dap-ui toggles", function()
    H.no_errors(function() require("dapui").toggle() end, 200)
    H.no_errors(function() require("dapui").toggle() end, 100)
  end)

  it("the cheatsheet picker survives <CR> on no match", function()
    require("cheatsheet").open()
    vim.wait(500, function() return vim.bo.filetype == "TelescopePrompt" end)
    local prompt = vim.api.nvim_get_current_buf()
    require("telescope.actions.state").get_current_picker(prompt):set_prompt("zzzz-no-such-entry")
    vim.wait(300)
    H.no_errors(function() require("telescope.actions").select_default(prompt) end, 100)
  end)
end)

describe("conform", function()
  after_each(H.reset)

  it("formats on save without error notifications (C++)", function()
    local path = H.write(dir, "fmt.cpp", { "int   main( ){return 0;}" })
    vim.cmd("edit " .. path)
    vim.bo.undofile = false
    H.no_errors(function() vim.cmd("write") end, 300)
    assert.are_not.same({ "int   main( ){return 0;}" }, vim.fn.readfile(path))
  end)

  it("respects :FormatToggle", function()
    vim.g.disable_autoformat = true
    local path = H.write(dir, "nofmt.cpp", { "int   main( ){return 0;}" })
    vim.cmd("edit " .. path)
    vim.bo.undofile = false
    vim.cmd("write")
    vim.g.disable_autoformat = false
    assert.are.same({ "int   main( ){return 0;}" }, vim.fn.readfile(path))
  end)
end)

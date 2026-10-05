local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")
local cfi = require("clang-format-indent")

describe("clang-format-indent parse_config", function()
  it("reads top-level scalar keys from --dump-config YAML", function()
    local cfg = cfi._parse_config({
      "---",
      "Language:        Cpp",
      "IndentWidth:     3",
      "UseTab:          Never",
      "TabWidth:        8",
      "BraceWrapping:",
      "  AfterClass:      false",
    })
    assert.are.equal("3", cfg.IndentWidth)
    assert.are.equal("Never", cfg.UseTab)
    assert.are.equal("8", cfg.TabWidth)
  end)

  it("ignores nested keys, so they can't shadow top-level ones", function()
    local cfg = cfi._parse_config({ "  IndentWidth: 99", "IndentWidth: 2" })
    assert.are.equal("2", cfg.IndentWidth)
  end)

  it("returns an empty table for no input", function()
    assert.are.same({}, cfi._parse_config({}))
  end)
end)

describe("clang-format-indent apply", function()
  if vim.fn.executable("clang-format") == 0 then
    pending("clang-format not installed")
    return
  end

  local function open_in(dir, style)
    H.write(dir, ".clang-format", style)
    local path = H.write(dir, "x.cpp", { "int main() {}" })
    vim.cmd("silent edit " .. vim.fn.fnameescape(path))
    cfi.apply()
    return vim.api.nvim_get_current_buf()
  end

  after_each(function() vim.cmd("silent! %bwipeout!") end)

  it("takes spaces and width from the project's .clang-format", function()
    local buf = open_in(H.tmpdir(), { "IndentWidth: 3", "UseTab: Never" })
    assert.are.equal(3, vim.bo[buf].shiftwidth)
    assert.are.equal(3, vim.bo[buf].softtabstop)
    assert.is_true(vim.bo[buf].expandtab)
  end)

  it("switches to hard tabs when UseTab is not Never", function()
    local buf = open_in(H.tmpdir(), { "IndentWidth: 4", "UseTab: Always", "TabWidth: 4" })
    assert.are.equal(4, vim.bo[buf].shiftwidth)
    assert.are.equal(4, vim.bo[buf].tabstop)
    assert.are.equal(0, vim.bo[buf].softtabstop)
    assert.is_false(vim.bo[buf].expandtab)
  end)

  it("does nothing for an unnamed buffer", function()
    vim.cmd("enew")
    vim.bo.shiftwidth = 7
    cfi.apply()
    assert.are.equal(7, vim.bo.shiftwidth)
  end)

  it("defines :ClangFormatIndentSync", function()
    assert.is_not_nil(vim.api.nvim_get_commands({}).ClangFormatIndentSync)
  end)
end)

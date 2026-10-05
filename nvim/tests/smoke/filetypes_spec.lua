-- Open a file of each type the config cares about: no errors (including the
-- async ones from linters), and the per-filetype setup is in place.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

local dir = H.tmpdir()
H.write(dir, ".clang-format", { "IndentWidth: 3", "UseTab: Never" })

local function open(name, lines)
  local path = H.write(dir, name, lines or { "" })
  H.no_errors(function() vim.cmd("edit " .. vim.fn.fnameescape(path)) end, 600)
  return vim.api.nvim_get_current_buf()
end

local function ts_active(buf)
  return vim.treesitter.highlighter.active[buf] ~= nil
end

describe("filetypes", function()
  after_each(H.reset)

  local cases = {
    { "main.c", "c", { "int main(void) { return 0; }" } },
    { "main.cpp", "cpp", { "#include <iostream>", "int main() { std::cout << 1; }" } },
    { "k.cu", "cuda", { "__global__ void k() {}" } },
    { "init.lua", "lua", { "local x = 1", "return x" } },
    { "a.py", "python", { "print(1)" } },
    { "a.sh", "sh", { "#!/bin/bash", "echo hi" } },
    { "notes.md", "markdown", { "# Title", "", "- [ ] item", "", "$x^2$" } },
    { "paper.tex", "tex", { "\\documentclass{article}", "\\begin{document}", "hi", "\\end{document}" } },
    { "default.latex", "pandoc-latex", { "$if(title)$\\title{$title$}$endif$" } },
    { "Makefile", "make", { "all:", "\techo hi" } },
    { "a.json", "json", { "{}" } },
    { "a.yaml", "yaml", { "a: 1" } },
    { "a.toml", "toml", { "a = 1" } },
    { "Dockerfile", "dockerfile", { "FROM alpine" } },
    { "COMMIT_EDITMSG", "gitcommit", { "subject" } },
    { "CMakeLists.txt", "cmake", { "project(x)" } },
    { "a.rs", "rust", { "fn main() {}" } },
    { "a.go", "go", { "package main" } },
    { "a.js", "javascript", { "let x = 1" } },
    { "a.ts", "typescript", { "let x: number = 1" } },
    { ".env", "env", { "SECRET=hunter2" } },
  }
  for _, c in ipairs(cases) do
    it(("opens %s as %s without errors"):format(c[1], c[2]), function()
      local buf = open(c[1], c[3])
      assert.are.equal(c[2], vim.bo[buf].filetype)
    end)
  end

  it("treesitter highlights the ensure_installed languages", function()
    for _, name in ipairs({ "main.c", "main.cpp", "init.lua", "notes.md", "Makefile", "a.rs", "a.js", "a.ts", "k.cu" }) do
      local buf = open(name, { "" })
      assert(ts_active(buf), "no treesitter highlighting for " .. name)
    end
  end)

  it("skips treesitter on files over 100 KB", function()
    local big = {}
    for i = 1, 6000 do big[i] = ("local v%d = %d -- padding padding"):format(i, i) end
    local buf = open("big.lua", big)
    assert.is_false(ts_active(buf))
  end)

  it("C/C++ indent follows the project's .clang-format, not the ftplugin default", function()
    for _, name in ipairs({ "main.c", "main.cpp", "k.cu" }) do
      local buf = open(name, { "" })
      assert.are.equal(3, vim.bo[buf].shiftwidth, name)
      assert.is_true(vim.bo[buf].cindent, name)
      assert.is_true(vim.bo[buf].expandtab, name)
    end
  end)

  it("runs clang-format once per C++ buffer, not twice", function()
    local cfi = require("clang-format-indent")
    local orig, n = cfi.apply, 0
    cfi.apply = function(...) n = n + 1 return orig(...) end
    open("once.cpp", { "" })
    cfi.apply = orig
    assert.are.equal(1, n)
  end)

  it("devdocs maps gK in its filetypes, and loads for them", function()
    open("main.cpp")
    assert.are.equal(1, H.map("n", "gK").buffer)
    open("a.json")
    local m = H.map("n", "gK")
    assert(not m or m.buffer == 0, "gK mapped in json")
  end)

  it("Makefiles use real tabs", function()
    local buf = open("Makefile")
    assert.is_false(vim.bo[buf].expandtab)
  end)

  it("markdownlint actually reports problems (args must keep --stdin)", function()
    if vim.fn.executable("markdownlint") == 0 then
      pending("markdownlint not installed")
      return
    end
    open("lint.md", { "# Title", "#Bad heading", "", "", "", "Text" })
    require("lint").try_lint("markdownlint")
    local function count()
      return #vim.tbl_filter(function(d) return d.source == "markdownlint" end, vim.diagnostic.get(0))
    end
    vim.wait(5000, function() return count() > 0 end, 50)
    assert.is_true(count() > 0)
  end)

  it("markdown soft-wraps", function()
    open("notes.md")
    assert.is_true(vim.wo.wrap)
    assert.is_true(vim.wo.linebreak)
  end)

  it("tex turns off hard wrapping and auto-indent", function()
    local buf = open("paper.tex")
    assert.are.equal(0, vim.bo[buf].textwidth)
    assert.is_false(vim.bo[buf].autoindent)
    assert.are.equal("", vim.bo[buf].indentexpr)
    assert.are.equal(2, vim.fn.exists(":VimtexCompile"))
  end)

  it("pandoc templates get tex syntax plus template matches, scoped to their window", function()
    open("default.latex")
    assert.are.equal("pandoc-latex", vim.b.current_syntax)
    assert.is_truthy(vim.fn.execute("syntax list"):find("\ntex%u"), "no TeX syntax underneath")
    local groups = vim.tbl_map(function(m) return m.group end, vim.fn.getmatches())
    assert.is_true(vim.tbl_contains(groups, "PandocVariable"))
    -- Same window, different buffer: the matches must not follow.
    open("main.c")
    assert.are.same({}, vim.fn.getmatches())
  end)

  it("cloaks .env values", function()
    open(".env", { "SECRET=hunter2" })
    local marks = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {})
    assert.is_true(#marks > 0)
  end)

  describe("obsidian vault", function()
    local vault = vim.fn.expand("~/vaults/content/personal")
    if vim.fn.isdirectory(vault) == 0 then
      pending("no vault at " .. vault)
      return
    end

    it("sets up vault notes, including the first one opened", function()
      -- Not written to disk; only the buffer name matters.
      vim.cmd("edit " .. vault .. "/__nvim_smoke_test__.md")
      assert.are.equal(1, H.map("n", "<leader>ch").buffer)
      assert.are.equal("Obsidian Smart Action", H.map("n", "<CR>").desc)
      assert.truthy(vim.bo.includeexpr:find("obsidian", 1, true)) -- gf follows note links
      vim.cmd("bwipeout!")
    end)

    it("does not map them outside the vault", function()
      open("notes.md")
      local ch = H.map("n", "<leader>ch")
      assert(not ch or ch.buffer == 0)
    end)
  end)
end)

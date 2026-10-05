-- config.markdown_graph: link parsing, scanning, and graph shaping.
local G = require("config.markdown_graph")

describe("config.markdown_graph", function()
  it("parses wiki links (alias/heading stripped) and relative .md links", function()
    local wiki, paths = G.parse_links(
      "[[A]] [[B|alias]] [[C#sec]] [x](d/E%20F.md) [y](https://x.com/g.md) [z](img.png)")
    assert.are.same({ "A", "B", "C" }, wiki)
    assert.are.same({ "d/E F.md" }, paths)
  end)

  local root
  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/sub", "p")
    local function w(p, s) vim.fn.writefile(vim.split(s, "\n"), root .. "/" .. p) end
    w("Home.md", "[[Mid]]\n```\n[[Fenced]]\n```")
    w("Mid.md", "[far](sub/Far.md)")
    w("sub/Far.md", "")
    w("Fenced.md", "")
    root = vim.uv.fs_realpath(root)
  end)

  it("scans links, ignoring ones inside code fences", function()
    local e = G.scan(root)
    assert.are.same({ [root .. "/Mid.md"] = true }, e[root .. "/Home.md"])
    assert.are.same({ [root .. "/sub/Far.md"] = true }, e[root .. "/Mid.md"])
  end)

  it("neighbourhood grows one hop per depth, following links both ways", function()
    local e = G.scan(root)
    local far = root .. "/sub/Far.md"
    assert.are.equal(2, vim.tbl_count(G.neighbourhood(e, far, 1)))
    assert.are.equal(3, vim.tbl_count(G.neighbourhood(e, far, 2)))
  end)

  it("emits a mermaid flowchart with the current note marked", function()
    local e = G.scan(root)
    local home = root .. "/Home.md"
    local lines = G.to_mermaid(e, G.neighbourhood(e, home, 1), home)
    assert.are.equal("flowchart LR", lines[1])
    assert.truthy(vim.tbl_contains(lines, "  n1 --> n2"))
    assert.truthy(vim.tbl_contains(lines, "  class n1 current"))
  end)
end)

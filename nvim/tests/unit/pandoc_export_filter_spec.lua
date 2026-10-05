-- pandoc/export.lua, the :MarkdownExport filter (pandoc conversion only; no
-- PDF compile, no mmdc).
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

local function convert(md, to)
  local r = vim.system({ "pandoc", "-f", "markdown", "-t", to or "beamer", "--lua-filter", root .. "/pandoc/export.lua" },
    { stdin = md, text = true }):wait()
  assert.are.equal(0, r.code, r.stderr)
  return r.stdout
end

describe("pandoc/export.lua", function()
  if vim.fn.executable("pandoc") == 0 then
    pending("pandoc not installed")
    return
  end

  it("turns > [!WARNING] callouts into alertblocks and keeps the body", function()
    local tex = convert("> [!WARNING]\n> Waiting on creds.\n")
    assert.truthy(tex:find("\\begin{alertblock}{Warning}", 1, true))
    assert.truthy(tex:find("Waiting on creds.", 1, true))
    assert.falsy(tex:find("[!WARNING]", 1, true))
  end)

  it("labels callouts in non-Beamer output instead of showing [!NOTE]", function()
    local tex = convert("> [!NOTE]\n> Read me.\n", "latex")
    assert.truthy(tex:find("\\textbf{Note:} Read me.", 1, true))
    assert.falsy(tex:find("[!NOTE]", 1, true))
  end)

  it("leaves ordinary block quotes alone", function()
    local tex = convert("> just a quote\n")
    assert.truthy(tex:find("\\begin{quote}", 1, true))
  end)

  it("keeps a mermaid block as code when mmdc fails", function()
    local tex = convert("---\nmermaid-bin: /nonexistent/mmdc\nmermaid-cache: " .. vim.fn.tempname()
      .. "\n---\n\n```mermaid\nflowchart LR\n  A --> B\n```\n")
    assert.truthy(tex:find("flowchart", 1, true))
    assert.falsy(tex:find("includegraphics", 1, true))
  end)
end)

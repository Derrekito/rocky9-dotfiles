-- config.export: frontmatter round-trip, option precedence, pandoc argv.
local fm = require("config.export.frontmatter")
local E = require("config.export")

-- Frontmatter is parsed by pandoc; machines without it skip those parts.
local have_pandoc = vim.fn.executable("pandoc") == 1

local NOTE = {
  "---",
  "title: Demo",
  "# a comment that must survive",
  "export:",
  "  format: slides",
  "  filters: [extra.lua]",
  "  pdf:",
  "    toc: true",
  "    template: tpl/report.latex",
  "  slides:",
  "    aspectratio: 43",
  "tags: [x]",
  "---",
  "",
  "# Body",
}

describe("config.export.frontmatter", function()
  if not have_pandoc then
    pending("pandoc not installed")
    return
  end
  it("reads YAML through pandoc", function()
    local m = fm.read(NOTE)
    assert.are.equal("Demo", m.title)
    assert.are.equal("slides", m.export.format)
    assert.are.same({ "extra.lua" }, m.export.filters)
    assert.are.equal(true, m.export.pdf.toc)
  end)

  it("returns {} without frontmatter", function()
    assert.are.same({}, fm.read({ "# just text" }))
  end)

  it("rewrites only the export block, keeping other keys and comments", function()
    local out = fm.with_export(NOTE, { format = "docx", docx = { toc = true } })
    assert.are.same({
      "---", "title: Demo", "# a comment that must survive",
      "export:", "  format: docx", "  docx:", "    toc: true",
      "tags: [x]", "---", "", "# Body",
    }, out)
    assert.are.equal("docx", fm.read(out).export.format)
  end)

  it("creates frontmatter when the note has none", function()
    local out = fm.with_export({ "# Body" }, { format = "pdf" })
    assert.are.same({ "---", "export:", "  format: pdf", "---", "", "# Body" }, out)
  end)

  it("quotes strings YAML would misread", function()
    local out = fm.with_export({ "# x" }, { output = "out: dir", flag = "true" })
    local m = fm.read(out)
    assert.are.equal("out: dir", m.export.output)
    assert.are.equal("true", m.export.flag)
  end)
end)

describe("config.export.resolve", function()
  if not have_pandoc then
    pending("pandoc not installed")
    return
  end
  local src = "/notes/demo.md"
  local meta = fm.read(NOTE)

  it("layers defaults < shared < per-format < overrides", function()
    local o = E.resolve(src, meta, "pdf", {})
    assert.is_true(o.toc)
    assert.are.equal("/notes/tpl/report.latex", o.template)
    assert.are.equal("/notes/extra.lua", o.filters[#o.filters])
    assert.is_false(E.resolve(src, meta, "pdf", { toc = false }).toc)
    assert.is_false(E.resolve(src, meta, "docx", {}).toc)
  end)

  it("names outputs per format beside the note, or under export.output", function()
    assert.are.equal("/notes/demo.pdf", E.resolve(src, meta, "pdf").out)
    assert.are.equal("/notes/demo.docx", E.resolve(src, meta, "docx").out)
    assert.are.equal("/notes/demo-slides.pdf", E.resolve(src, meta, "slides").out)
    assert.are.equal("/notes/build/demo.docx", E.resolve(src, meta, "docx", { output = "build" }).out)
    assert.are.equal("/tmp/x.docx", E.resolve(src, meta, "docx", { output = "/tmp/x.docx" }).out)
  end)

  it("default-filters: false drops the built-in filters", function()
    local o = E.resolve(src, meta, "docx", { ["default-filters"] = false })
    assert.are.same({ "/notes/extra.lua" }, o.filters)
  end)
end)

describe("config.export docx template", function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local src = dir .. "/n.md"
  local function ref(meta, ov) return E.resolve(src, meta, "docx", ov)["reference-doc"] end

  it("uses pandoc's default styles when there is no template", function()
    assert.is_nil(ref({}))
  end)

  it("picks up template.docx beside the note", function()
    vim.fn.writefile({}, dir .. "/template.docx")
    assert.are.equal(dir .. "/template.docx", ref({}))
  end)

  it("frontmatter template: overrides it, template: false disables it", function()
    assert.are.equal("/x/brand.docx", ref({ export = { docx = { template = "/x/brand.docx" } } }))
    assert.are.equal("/x/old.docx", ref({ export = { docx = { ["reference-doc"] = "/x/old.docx" } } }))
    assert.is_nil(ref({ export = { docx = { template = false } } }))
  end)

  it("ignores a shared LaTeX template for docx", function()
    assert.are.equal(dir .. "/template.docx", ref({ export = { template = "report.latex" } }))
  end)
end)

describe("config.export.steps", function()
  if not have_pandoc then
    pending("pandoc not installed")
    return
  end
  local src = "/notes/demo.md"
  local meta = fm.read(NOTE)
  local function pandoc_argv(format, ov)
    for _, s in ipairs(E.steps(E.resolve(src, meta, format, ov))) do
      if s.desc == "pandoc" then return table.concat(s.cmd, " ") end
    end
  end

  it("slides: beamer, frontmatter aspectratio, rose-pine highlighting", function()
    local cmd = pandoc_argv("slides")
    assert.truthy(cmd:find("--to beamer", 1, true))
    assert.truthy(cmd:find("-V aspectratio=43", 1, true))
    -- Full theme where minted exists, its TikZ-only parts otherwise.
    for k, v in pairs(E.beamer_theme()) do
      assert.truthy(cmd:find("-V " .. k .. "=" .. v, 1, true))
    end
    assert.truthy(cmd:find(E.highlight_flag() .. "=", 1, true))
  end)

  it("pdf: goes through .tex and latexmk with lualatex", function()
    local steps = E.steps(E.resolve(src, meta, "pdf"))
    local last = steps[#steps]
    assert.are.equal("lualatex", last.desc)
    assert.truthy(table.concat(last.cmd, " "):find("-lualatex -shell-escape", 1, true))
    assert.truthy(pandoc_argv("pdf"):find("--toc", 1, true))
    assert.truthy(pandoc_argv("pdf"):find("--standalone", 1, true))
  end)

  it("reports tools that aren't installed instead of running", function()
    assert.are.same({ "no-such-tool-xyz" }, E.missing_tools({ { cmd = { "no-such-tool-xyz", "a" } }, { fn = function() end } }))
    assert.are.same({}, E.missing_tools({ { cmd = { "sh", "-c", "true" } } }))
    -- Programs a step runs indirectly count too (pandoc's PDF engine).
    assert.are.same({ "no-such-engine-xyz" }, E.missing_tools({ { cmd = { "sh" }, needs = { "no-such-engine-xyz" } } }))
  end)

  it("passes unknown keys straight to pandoc", function()
    local cmd = pandoc_argv("docx", { ["shift-heading-level-by"] = "1", ["standalone"] = true })
    assert.truthy(cmd:find("--shift-heading-level-by=1", 1, true))
    assert.truthy(cmd:find("--standalone", 1, true))
  end)
end)

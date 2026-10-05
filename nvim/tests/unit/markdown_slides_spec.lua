-- config.markdown_slides: how a note is cut into slides.
local S = require("config.markdown_slides")

local function titles(slides)
  return vim.tbl_map(function(s) return s.lines[1] end, slides)
end

describe("config.markdown_slides.split", function()
  it("splits on # and ## headings, drops frontmatter, ignores # in fences", function()
    local slides = S.split({
      "---", "tags: [x]", "---", "", "# Title", "intro", "", "## One", "```sh", "# comment", "```", "### sub", "## Two",
    })
    assert.are.same({ "# Title", "## One", "## Two" }, titles(slides))
    assert.are.equal(5, slides[1].start)
    assert.are.same({ "## One", "```sh", "# comment", "```", "### sub" }, slides[2].lines)
  end)

  it("uses --- / end_slide breaks instead when the note has any", function()
    local slides = S.split({ "# A", "## not a split", "---", "B", "<!-- end_slide -->", "", "C" })
    assert.are.same({ "# A", "B", "C" }, titles(slides))
    assert.are.equal(7, slides[3].start)
  end)
end)

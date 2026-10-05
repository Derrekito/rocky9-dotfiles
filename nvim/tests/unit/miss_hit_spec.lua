local mh = require("config.lint.miss_hit")
local sev = vim.diagnostic.severity

describe("mh_style parser", function()
  it("parses positioned style issues (0-based line)", function()
    local d = mh.parse_style("foo.m:12:5: style: whitespace around operator\n", 0)
    assert.are.same({ {
      source = "mh_style", lnum = 11, col = 5, message = "whitespace around operator", severity = sev.WARN,
    } }, d)
  end)

  it("parses file-level issues onto line 0", function()
    local d = mh.parse_style("foo.m: style: file should end with a newline", 0)
    assert.are.equal(1, #d)
    assert.are.equal(0, d[1].lnum)
    assert.are.equal("file should end with a newline", d[1].message)
  end)

  it("skips the MISS_HIT summary banner", function()
    local d = mh.parse_style("MISS_HIT Style Summary: 1 file(s) analysed, 2 style issue(s)\n", 0)
    assert.are.same({}, d)
  end)

  it("handles multiple lines", function()
    local d = mh.parse_style("a.m:1:1: style: one\na.m:2:3: style: two\n", 0)
    assert.are.equal(2, #d)
    assert.are.equal(1, d[2].lnum)
  end)
end)

describe("mh_lint parser", function()
  it("maps high/medium/low to ERROR/WARN/INFO", function()
    local out = table.concat({
      "a.m:3:4: check (high): bad thing [rule_a]",
      "a.m:5:1: check (medium): meh thing [rule_b]",
      "a.m:7:2: check (low): tiny thing [rule_c]",
    }, "\n")
    local d = mh.parse_lint(out, 0)
    assert.are.equal(3, #d)
    assert.are.equal(sev.ERROR, d[1].severity)
    assert.are.equal(2, d[1].lnum)
    assert.are.equal(4, d[1].col)
    assert.are.equal("bad thing [rule_a]", d[1].message)
    assert.are.equal(sev.WARN, d[2].severity)
    assert.are.equal(sev.INFO, d[3].severity)
  end)

  it("defaults unknown severities to WARN and skips the banner", function()
    local d = mh.parse_lint("MISS_HIT Lint Summary: ...\na.m:1:1: check (weird): x", 0)
    assert.are.equal(1, #d)
    assert.are.equal(sev.WARN, d[1].severity)
  end)

  it("ignores unparseable lines", function()
    assert.are.same({}, mh.parse_lint("garbage\n\n", 0))
  end)
end)

describe("MISS_HIT linter definitions", function()
  for _, name in ipairs({ "mh_style", "mh_lint" }) do
    it(name .. " passes the real file path (no stdin mode)", function()
      local l = mh[name]
      assert.are.equal(name, l.cmd)
      assert.is_false(l.stdin)
      assert.is_true(l.append_fname)
      assert.are.equal("function", type(l.parser))
    end)
  end
end)

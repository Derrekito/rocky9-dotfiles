local guifont = require("config.guifont")

describe("guifont.bump", function()
  it("increments the size", function()
    assert.are.equal("JetBrains Mono:h13", guifont.bump("JetBrains Mono:h12", 1))
  end)

  it("decrements and never goes below 1", function()
    assert.are.equal("Iosevka:h11", guifont.bump("Iosevka:h12", -1))
    assert.are.equal("Iosevka:h1", guifont.bump("Iosevka:h1", -5))
  end)

  it("keeps fractional sizes and other options", function()
    assert.are.equal("Iosevka:h13.5:b", guifont.bump("Iosevka:h12.5:b", 1))
  end)

  it("bumps every font in a fallback list", function()
    assert.are.equal("A:h11,B:h15", guifont.bump("A:h10,B:h14", 1))
  end)

  it("returns nil when there is no size", function()
    assert.is_nil(guifont.bump("", 1))
    assert.is_nil(guifont.bump("Iosevka", 1))
    assert.is_nil(guifont.bump(nil, 1))
  end)
end)

describe("guifont.increase", function()
  it("sets 'guifont'", function()
    vim.o.guifont = "Mono:h10"
    guifont.increase(2)
    assert.are.equal("Mono:h12", vim.o.guifont)
  end)

  it("notifies instead of erroring when there is no size", function()
    vim.o.guifont = ""
    local got
    local orig = vim.notify
    vim.notify = function(msg) got = msg end
    guifont.increase(1)
    vim.notify = orig
    assert.is_truthy(got)
    assert.are.equal("", vim.o.guifont)
  end)
end)

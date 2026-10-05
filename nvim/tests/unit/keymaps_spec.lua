-- config.keymaps in isolation (no plugins).
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

describe("config.keymaps", function()
  package.loaded["config.keymaps"] = nil
  require("config.keymaps")

  it("sets <Space> as leader", function()
    assert.are.equal(" ", vim.g.mapleader)
  end)

  local expected = {
    { "n", "<leader>pv" }, { "v", "J" }, { "v", "K" }, { "i", "<C-c>" },
    { "n", "J" }, { "n", "<C-d>" }, { "n", "<C-u>" }, { "n", "n" }, { "n", "N" },
    { "x", "<leader>p" }, { "n", "<leader>y" }, { "v", "<leader>y" }, { "n", "<leader>Y" },
    { "n", "<leader>D" }, { "v", "<leader>D" }, { "n", "Q" }, { "n", "<leader>f" },
    { "n", "<C-k>" }, { "n", "<C-j>" }, { "n", "<leader>k" }, { "n", "<leader>j" },
    { "n", "<leader>s" }, { "n", "<leader>S" }, { "n", "<leader>x" },
    { "n", "<leader><leader>" }, { "n", "<C-a>" }, { "n", "<leader>-" }, { "n", "<leader>|" },
    { "n", "<leader>\\" }, { "n", "sh" }, { "n", "sj" }, { "n", "sk" }, { "n", "sl" },
    { "n", "Sh" }, { "n", "Sj" }, { "n", "Sk" }, { "n", "Sl" }, { "n", "<esc>" },
    { "n", "<leader>dn" }, { "n", "<leader>dp" }, { "n", "<leader>de" }, { "n", "<leader>q" },
    { "n", "<leader>dq" }, { "n", "<leader>lr" }, { "n", "<leader>lR" }, { "n", "<leader>+" },
  }
  for _, e in ipairs(expected) do
    it(("maps %s %s"):format(e[1], e[2]), function()
      assert.is_not_nil(H.map(e[1], e[2]))
    end)
  end

  it("does not map <leader>d itself (it is a prefix of the diagnostic maps)", function()
    assert.is_nil(H.map("n", "<leader>d"))
    assert.is_nil(H.map("v", "<leader>d"))
  end)

  it("<Esc> clears search highlight without echoing a command", function()
    assert.are.equal("<cmd>nohlsearch<cr>", H.map("n", "<esc>").rhs:lower())
  end)

  it("<leader><leader> exists from startup, not only after a BufLeave", function()
    local m = H.map("n", "<leader><leader>")
    assert.are.equal(0, m.buffer)
  end)

  it("<leader><leader> refuses to :source a non-Lua/Vim buffer", function()
    vim.cmd("enew")
    vim.bo.filetype = "markdown"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# nvim" })
    H.no_errors(H.map("n", "<leader><leader>").callback)
    vim.cmd("bwipeout!")
  end)

  it("<leader>+ does not raise (it used to run an invalid :highlight)", function()
    vim.o.guifont = "Mono:h10"
    H.no_errors(H.map("n", "<leader>+").callback)
    assert.are.equal("Mono:h11", vim.o.guifont)
  end)

  it("opening help maps <CR> to follow tags, silently", function()
    vim.cmd("messages clear")
    vim.cmd("silent help help")
    assert.are.equal("<C-]>", H.map("n", "<CR>").rhs)
    assert.is_nil(vim.fn.execute("messages"):find("Help filetype detected"))
    vim.cmd("helpclose")
  end)

  it("uses OSC 52 for copy and the + register by default", function()
    local cb = vim.g.clipboard
    assert.are.equal("function", type(cb.copy["+"]))
    assert.is_not_nil(cb.paste["+"])
    assert.is_truthy(vim.o.clipboard:find("unnamedplus"))
  end)

  it("pastes via wl-paste locally and OSC 52 over SSH", function()
    local function load_with(env)
      local saved = { SSH_TTY = vim.env.SSH_TTY, SSH_CONNECTION = vim.env.SSH_CONNECTION }
      vim.env.SSH_TTY, vim.env.SSH_CONNECTION = env, env
      package.loaded["config.keymaps"] = nil
      require("config.keymaps")
      vim.env.SSH_TTY, vim.env.SSH_CONNECTION = saved.SSH_TTY, saved.SSH_CONNECTION
      return vim.g.clipboard.paste["+"]
    end
    assert.are.equal("function", type(load_with("/dev/pts/9")))
    assert.are.same({ "wl-paste", "--no-newline" }, load_with(nil))
  end)
end)

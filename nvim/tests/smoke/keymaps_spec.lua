-- Keymaps once every plugin is loaded: present, not shadowed, not
-- prefix-conflicting, and the ones with custom logic run cleanly.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

describe("keymaps (full config)", function()
  it("lazy key stubs load their plugin and hand over to its real mapping", function()
    if not H.has_lazy() then
      pending("no lazy.nvim: plugins load at startup, so there are no key stubs")
      return
    end
    local Config = require("lazy.core.config")
    assert.is_nil(Config.plugins["zen-mode.nvim"]._.loaded)
    vim.api.nvim_feedkeys(vim.keycode("<leader>zz"), "mx", false)
    vim.wait(500)
    assert.is_truthy(Config.plugins["zen-mode.nvim"]._.loaded)
    assert.are.equal("<cmd>zenmode<cr>", H.map("n", "<leader>zz").rhs:lower())
    pcall(vim.cmd, "ZenMode") -- close it again
  end)

  it("has the plugin keymaps", function()
    local expected = {
      { "n", "<leader>a" }, { "n", "<C-e>" }, { "n", "<leader>1" }, { "n", "<leader>4" }, -- harpoon
      { "n", "<leader>ph" }, { "n", "<leader>pf" }, { "n", "<leader>en" }, { "n", "<leader>ep" },
      { "n", "<leader>mg" },                                             -- telescope
      { "n", "<leader>o" }, { "n", "<leader>O" }, { "n", "<leader>po" }, -- aerial
      { "n", "<leader>tt" }, { "n", "<leader>tn" }, { "n", "<leader>tp" }, -- trouble
      { "n", "<leader>zz" }, { "n", "<leader>cs" }, { "n", "<leader>gs" }, { "n", "<leader>dg" },
      { "n", "<leader>db" }, { "n", "<leader>dc" }, { "n", "<leader>dO" }, { "n", "<leader>di" },
      { "n", "<leader>do" }, { "n", "<leader>dt" }, { "n", "<leader>dr" }, -- dap
      { "n", "<leader>9x" }, { "n", "<leader>9s" }, { "x", "<leader>9v" },
      { "n", "<leader>pv" }, { "n", "<leader>f" }, { "n", "<leader>ta" },
    }
    local missing = {}
    for _, e in ipairs(expected) do
      if not H.map(e[1], e[2]) then table.insert(missing, e[1] .. " " .. e[2]) end
    end
    assert(#missing == 0, "missing: " .. table.concat(missing, ", "))
  end)

  it("<leader>pv toggles nvim-tree (not netrw's :Ex)", function()
    assert.are.equal("<cmd>nvimtreetoggle<cr>", H.map("n", "<leader>pv").rhs:lower())
  end)

  it("<leader>f formats with conform", function()
    assert.are.equal("Format buffer", H.map("n", "<leader>f").desc)
  end)

  it("leaves Neovim's ]d / [d diagnostic jumps alone", function()
    assert.is_truthy(H.map("n", "]d").desc:find("next diagnostic"))
    assert.is_truthy(H.map("n", "[d").desc:find("previous diagnostic"))
  end)

  it("does not map bare <Space> (the leader)", function()
    assert.is_nil(H.map("n", "<Space>"))
  end)

  for _, mode in ipairs({ "n", "x", "o" }) do
    it(("no <leader> map in mode %s is a prefix of another (timeoutlen stalls)"):format(mode), function()
      local lhss = {}
      for lhs in pairs(H.global_maps(mode)) do
        if lhs:sub(1, 1) == " " then table.insert(lhss, lhs) end
      end
      local conflicts = {}
      for _, a in ipairs(lhss) do
        for _, b in ipairs(lhss) do
          if a ~= b and b:sub(1, #a) == a then
            table.insert(conflicts, ("%q shadows %q"):format(a, b))
          end
        end
      end
      table.sort(conflicts)
      assert(#conflicts == 0, table.concat(conflicts, "\n"))
    end)
  end

  it("LSP buffers get <leader>ds as document symbols, over dap", function()
    H.load("nvim-dap")
    vim.cmd("enew")
    vim.api.nvim_exec_autocmds("LspAttach", { buffer = 0, data = { client_id = 0 } })
    local m = H.map("n", "<leader>ds")
    assert.are.equal(1, m.buffer)
    assert.is_truthy(m.rhs:find("lsp_document_symbols"))
    vim.cmd("bwipeout!")
  end)

  it("harpoon's slot jumps don't error on an empty slot", function()
    H.load("harpoon")
    H.no_errors(H.map("n", "<leader>4").callback)
  end)

  describe("telescope pickers open and close cleanly", function()
    H.load("telescope.nvim", "cheatsheet")
    local function close_pickers()
      vim.wait(1000, function() return vim.bo.filetype == "TelescopePrompt" end)
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        -- Closing one picker wipes its other buffers; skip those.
        if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "TelescopePrompt" then
          pcall(require("telescope.actions").close, b)
        end
      end
      vim.cmd("stopinsert")
    end

    for _, lhs in ipairs({ "<leader>pf", "<leader>ph", "<leader>en", "<leader>ep", "<leader>mg", "<leader>cs" }) do
      it(lhs, function()
        H.no_errors(function()
          local m = H.map("n", lhs)
          if m.callback then m.callback() else vim.cmd(vim.api.nvim_replace_termcodes(m.rhs, true, true, true):gsub("^:", ""):gsub("\r$", "")) end
        end, 300)
        close_pickers()
        H.reset()
      end)
    end

    it("<leader>ep lists the installed plugins' directory", function()
      local builtin = require("telescope.builtin")
      local orig = builtin.find_files
      local got
      builtin.find_files = function(opts) got = opts end
      H.map("n", "<leader>ep").callback()
      builtin.find_files = orig
      local data = vim.fn.stdpath("data")
      local want = H.has_lazy() and vim.fs.joinpath(data, "lazy") or vim.fs.joinpath(data, "site", "pack", "plugins")
      assert.are.equal(want, got.cwd)
    end)
  end)

  it("fugitive's <leader>l runs `git log`, not `git git log`", function()
    local got
    H.load("fugitive")
    vim.api.nvim_create_user_command("Git", function(a) got = a.args end, { nargs = "*", force = true })
    vim.cmd("enew")
    vim.bo.buftype = "nofile"
    vim.bo.filetype = "fugitive"
    vim.api.nvim_exec_autocmds("BufWinEnter", { group = "Derrekito_Fugitive" })
    H.map("n", "<leader>l").callback()
    assert.is_truthy(got:match("^log "))
    vim.cmd("bwipeout!")
  end)
end)

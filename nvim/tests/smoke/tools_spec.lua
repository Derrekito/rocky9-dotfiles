-- External programs the config shells out to. A missing one is reported as
-- pending (so you see it in the output) rather than failing the run: they
-- are per-machine installs, not config bugs.
local function check(label, cmd)
  if vim.fn.executable(cmd) == 1 then
    it(label .. ": " .. cmd, function() end)
  else
    pending(label .. ": " .. cmd .. " not on PATH")
  end
end

describe("external tools", function()
  describe("formatters (conform)", function()
    local ok, lazy = pcall(require, "lazy")
    if ok then lazy.load({ plugins = { "conform.nvim" } }) end
    local conform = require("conform")
    local seen = {}
    for _, list in pairs(require("conform").formatters_by_ft) do
      for _, name in ipairs(type(list) == "table" and list or {}) do
        if not seen[name] then
          seen[name] = true
          local info = conform.get_formatter_info(name)
          if info.available then
            it("formatter " .. name, function() end)
          else
            pending("formatter " .. name .. ": " .. tostring(info.available_msg))
          end
        end
      end
    end
  end)

  describe("linters (nvim-lint)", function()
    for _, cmd in ipairs({ "cppcheck", "shellcheck", "markdownlint", "checkmake", "mh_lint", "mh_style",
      "cmakelint", "hadolint", "yamllint", "gitlint" }) do
      check("linter", cmd)
    end
  end)

  describe("everything else", function()
    check("telescope multigrep", "rg")
    check("telescope-fzf-native build", "make")
    check("clang-format-indent", "clang-format")
    check("clipboard paste (local)", "wl-paste")
    check("vimtex", "latexmk")
    check("vimtex viewer", "zathura")
    check("cmake LSP (pipx)", "cmake-language-server")
    check("git", "git")
  end)

  describe("debug adapters (nvim-dap)", function()
    local ok, lazy = pcall(require, "lazy")
    if ok then lazy.load({ plugins = { "nvim-dap" } }) end
    local dap = require("dap")
    for _, name in ipairs({ "python", "cppdbg" }) do
      local resolved
      dap.adapters[name](function(a) resolved = a end, {})
      local ok = resolved.command and vim.fn.executable(resolved.command) == 1
      if ok and name == "python" and resolved.command == "python" then
        ok = vim.fn.system({ "python", "-c", "import debugpy" }) and vim.v.shell_error == 0
      end
      if ok then
        it(name .. ": " .. resolved.command, function() end)
      else
        pending(name .. ": adapter " .. tostring(resolved.command) .. " unavailable (:MasonInstall debugpy cpptools)")
      end
    end
  end)

  describe("Mason tools", function()
    local registry = require("mason-registry")
    for _, name in ipairs(require("config.mason_tools").tools) do
      if registry.is_installed(name) then
        it("mason: " .. name, function() end)
      else
        pending("mason: " .. name .. " not installed yet (installs in the background on startup)")
      end
    end
  end)
end)

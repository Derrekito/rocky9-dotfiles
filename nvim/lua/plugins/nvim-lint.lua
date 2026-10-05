-- nvim-lint - Modern linting for Neovim
-- Complements LSP with additional linters
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    -- Configure linters by filetype
    -- NOTE: Only use linters that ADD value beyond LSP
    lint.linters_by_ft = {
      -- C/C++ (cppcheck adds static analysis beyond clangd).
      -- cpplint intentionally dropped: it enforces Google style (attached
      -- braces) which conflicts with our Allman/BSD ~/.clang-format.
      -- clang-tidy runs inside clangd via --clang-tidy.
      c = { "cppcheck" },
      cpp = { "cppcheck" },

      -- Shell scripts (shellcheck is THE standard)
      sh = { "shellcheck" },
      bash = { "shellcheck" },

      -- Markdown (markdownlint for style)
      markdown = { "markdownlint" },

      -- Makefile (checkmake for best practices)
      make = { "checkmake" },

      -- MATLAB (MISS_HIT lint + style checks)
      matlab = { "mh_lint", "mh_style" },

      -- CMake
      cmake = { "cmakelint" },

      -- Dockerfile
      dockerfile = { "hadolint" },

      -- YAML
      yaml = { "yamllint" },

      -- Git commit messages
      gitcommit = { "gitlint" },

      -- Python - only add linters NOT covered by pylsp
      -- (pylsp already does pyflakes, pycodestyle, mypy)
      -- python = { "ruff" }, -- Uncomment if you want ruff (very fast)

      -- JavaScript/TypeScript - only if NOT using eslint via LSP
      -- javascript = { "eslint_d" },
      -- typescript = { "eslint_d" },
    }

    -- Create autocommand for linting
    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
      group = lint_augroup,
      callback = function()
        -- Only lint if file exists and is not too large
        local max_filesize = 100 * 1024 -- 100 KB
        local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(0))
        if ok and stats and stats.size < max_filesize then
          lint.try_lint()
        end
      end,
    })

    -- Manual lint command
    vim.api.nvim_create_user_command("Lint", function()
      lint.try_lint()
    end, {
      desc = "Trigger linting for current file",
    })

    -- Configuration for specific linters
    -- Cppcheck: enable all checks, treat as warnings not errors
    lint.linters.cppcheck.args = {
      "--enable=all",
      "--inline-suppr",
      "--suppress=missingIncludeSystem",
      "--suppress=unmatchedSuppression",
      "--quiet",
      "--template={file}:{line}:{column}: {severity}: {message} [{id}]",
    }

    -- Shellcheck: disable some overly strict warnings
    lint.linters.shellcheck.args = {
      "--format=json",
      "--shell=bash",
      "--exclude=SC2086", -- Double quote to prevent globbing (often too strict)
      "-",
    }

    -- MISS_HIT (MATLAB) linters; see lua/config/lint/miss_hit.lua.
    local miss_hit = require("config.lint.miss_hit")
    lint.linters.mh_style = miss_hit.mh_style
    lint.linters.mh_lint = miss_hit.mh_lint

    -- Markdownlint: customize rules.
    -- NOTE: this replaces nvim-lint's default args entirely, so "--stdin" has
    -- to be repeated here. Without it markdownlint gets no input, emits
    -- nothing, and the linter silently reports zero diagnostics. A bare "--"
    -- does not work: markdownlint then treats the rest as file paths.
    lint.linters.markdownlint.args = {
      "--disable",
      "MD013", -- Line length (handled by prettier)
      "MD041", -- First line in file should be a top-level heading
      "--stdin",
    }

    -- Drop linters whose executable isn't installed. nvim-lint raises an
    -- ERROR notification on every try_lint for a missing binary, and the
    -- autocmd above lints on every BufEnter, so one absent tool (hadolint,
    -- gitlint, ...) means an error popup each time you enter such a buffer.
    local function available(name)
      local ok, linter = pcall(function() return lint.linters[name] end)
      if not ok or not linter then return false end
      if type(linter) == "function" then linter = linter() end
      local cmd = linter.cmd
      if type(cmd) == "function" then cmd = cmd() end
      return type(cmd) == "string" and vim.fn.executable(cmd) == 1
    end
    for ft, names in pairs(lint.linters_by_ft) do
      lint.linters_by_ft[ft] = vim.tbl_filter(available, names)
    end
  end,
}

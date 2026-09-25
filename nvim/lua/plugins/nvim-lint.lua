-- nvim-lint - Modern linting for Neovim, pinned to the last commit before it
-- required 0.9.5. Complements LSP with additional linters
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
    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(0))
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

-- mh_style: MISS_HIT style checker (not bundled with nvim-lint).
-- append_fname = true passes the buffer's real path so mh_style operates on
-- the file (it has no stdin mode) and can walk up to find miss_hit.cfg.
-- Without it, mh_style runs against cwd with no file and crashes / cannot
-- locate the config.
lint.linters.mh_style = {
  cmd = "mh_style",
  stdin = false,
  append_fname = true,
  args = { "--brief" },
  stream = "stdout",
  ignore_exitcode = true,
  parser = function(output, bufnr)
    local diagnostics = {}
    local fname = vim.api.nvim_buf_get_name(bufnr)
    for line in output:gmatch("[^\n]+") do
      local f, lnum, col, msg = line:match("^(.-):(%d+):(%d+):%s*style:%s*(.*)$")
      if f then
        table.insert(diagnostics, {
          source = "mh_style",
          lnum = tonumber(lnum) - 1,
          col = tonumber(col),
          message = msg,
          severity = vim.diagnostic.severity.WARN,
        })
      else
        f, msg = line:match("^(.-): style:%s*(.*)$")
        if f and not line:match("^MISS_HIT") then
          table.insert(diagnostics, {
            source = "mh_style",
            lnum = 0,
            col = 0,
            message = msg,
            severity = vim.diagnostic.severity.WARN,
          })
        end
      end
    end
    return diagnostics
  end,
}

-- mh_lint: MISS_HIT semantic/code linter (not bundled with nvim-lint).
-- Output: file:line:col: check (severity): message [rule]
-- append_fname = true so it gets the real path (no stdin mode; needed for
-- miss_hit.cfg lookup).
lint.linters.mh_lint = {
  cmd = "mh_lint",
  stdin = false,
  append_fname = true,
  args = { "--brief" },
  stream = "stdout",
  ignore_exitcode = true,
  parser = function(output, _)
    local diagnostics = {}
    local sev_map = {
      ["high"] = vim.diagnostic.severity.ERROR,
      ["medium"] = vim.diagnostic.severity.WARN,
      ["low"] = vim.diagnostic.severity.INFO,
    }
    for line in output:gmatch("[^\n]+") do
      if not line:match("^MISS_HIT") then
        local lnum, col, level, msg = line:match("^.-:(%d+):(%d+):%s*%a+%s*%((%a+)%):%s*(.*)$")
        if lnum then
          table.insert(diagnostics, {
            source = "mh_lint",
            lnum = tonumber(lnum) - 1,
            col = tonumber(col),
            message = msg,
            severity = sev_map[level] or vim.diagnostic.severity.WARN,
          })
        end
      end
    end
    return diagnostics
  end,
}

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

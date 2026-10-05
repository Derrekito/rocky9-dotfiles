-- conform.nvim - Modern formatting for Neovim
-- Replaces ALE fixers with better performance and LSP integration
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  -- Our own commands are listed too: they are defined in config(), which
  -- otherwise doesn't run until the first write.
  cmd = { "ConformInfo", "FormatToggle", "FormatStatus" },
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = "",
      desc = "Format buffer",
    },
  },
  config = function()
    require("conform").setup({
      -- Formatters by filetype
      formatters_by_ft = {
        -- LaTeX
        tex = { "latexindent" },

        -- BibTeX
        bib = { "bibtex-tidy" },

        -- Lua
        lua = { "stylua" },

        -- Python (black is already configured in pylsp, but this is backup)
        python = { "isort", "black" },

        -- C/C++/CUDA
        c = { "clang_format" },
        cpp = { "clang_format" },
        cuda = { "clang_format" },

        -- CMake
        cmake = { "gersemi" },

        -- JavaScript/TypeScript
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },

        -- Web
        html = { "prettier" },
        css = { "prettier" },
        json = { "prettier" },

        -- Markdown
        markdown = { "prettier-latex" },

        -- MATLAB (MISS_HIT style fixer)
        matlab = { "mh_style" },

        -- Shell
        sh = { "shfmt" },
        bash = { "shfmt" },

        -- Rust
        rust = { "rustfmt" },

        -- Go
        go = { "gofmt", "goimports" },

        -- YAML
        yaml = { "prettier" },

        -- TOML
        toml = { "taplo" },

        -- Disable formatting for env files (no formatter needed)
        env = {},
        dotenv = {},
      },

      -- Format on save
      format_on_save = function(bufnr)
        -- Disable with a global or buffer-local variable
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return {
          timeout_ms = 500,
          lsp_format = "fallback", -- Use LSP formatter if conform formatter not available
          notify_on_error = true, -- Show error notification when formatter fails
        }
      end,

      -- Notify when formatter is not available
      notify_on_error = true,
      notify_no_formatters = true,

      -- Formatter configurations
      formatters = {
        latexindent = {
          command = "latexindent",
          args = { "-l", os.getenv("HOME") .. "/.indentconfig.yaml", "-" },
          stdin = true,
        },
        ["bibtex-tidy"] = {
          command = "bibtex-tidy",
          args = {
            "--curly",           -- Use curly braces
            "--numeric",         -- Use numeric citations
            "--space=2",         -- 2 space indent
            "--align=13",        -- Align values
            "--blank-lines",     -- Add blank lines between entries
            "--sort-fields",     -- Sort fields in consistent order
            "--no-remove-dupe-fields",  -- Keep duplicate fields (safer)
            "--quiet",           -- Suppress warnings
            "-"                  -- Read from stdin
          },
          stdin = true,
        },
        shfmt = {
          prepend_args = { "-i", "2", "-ci" }, -- 2 spaces, indent switch cases
        },
        clang_format = {
          prepend_args = { "--style=file" }, -- Use .clang-format if exists
        },
        ["prettier-latex"] = {
          command = vim.fn.expand("~/.local/bin/prettier-latex"),
        },
      },
    })

    -- Command to toggle format on save
    vim.api.nvim_create_user_command("FormatToggle", function()
      if vim.b.disable_autoformat or vim.g.disable_autoformat then
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
        print("Format on save enabled")
      else
        vim.b.disable_autoformat = true
        vim.g.disable_autoformat = true
        print("Format on save disabled")
      end
    end, {
      desc = "Toggle format on save",
    })

    -- Command to check formatter status for current buffer
    vim.api.nvim_create_user_command("FormatStatus", function()
      local conform = require("conform")
      local names = conform.formatters_by_ft[vim.bo.filetype] or {}
      if type(names) == "function" then
        names = names(0)
      end
      names = vim.tbl_filter(function(n) return type(n) == "string" end, names)
      if #names == 0 then
        vim.notify("No formatters available for this filetype", vim.log.levels.WARN)
        return
      end

      local status_lines = { "Formatters for " .. vim.bo.filetype .. ":" }
      for _, name in ipairs(names) do
        local info = conform.get_formatter_info(name, 0)
        table.insert(status_lines, string.format("  %s %s", info.available and "✓" or "✗", name))
      end
      vim.notify(table.concat(status_lines, "\n"), vim.log.levels.INFO)
    end, {
      desc = "Show formatter status for current buffer",
    })
  end,
}

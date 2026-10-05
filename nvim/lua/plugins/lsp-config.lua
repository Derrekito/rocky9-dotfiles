return {
  -- Mason configuration for LSP server management
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
          }
        }
      })
      require("config.mason_tools").ensure_installed()
    end
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    lazy = false,
    config = function()
      -- mason-lspconfig v2.x: this plugin now only handles install + auto-enable.
      -- The old `handlers` API was removed; per-server config goes through the
      -- native vim.lsp.config() API (Neovim 0.11+) below.
      require("mason-lspconfig").setup {
        ensure_installed = { 'clangd', 'rust_analyzer', 'gopls', 'bashls', 'lua_ls', 'marksman', 'pylsp', 'jsonls', 'texlab', 'harper_ls' },
        -- Enables an LSP for every Mason package that has one, including
        -- the non-LSP tools from lua/config/mason_tools.lua. taplo's TOML
        -- server is welcome; stylua's would just duplicate conform.
        automatic_enable = { exclude = { "stylua" } },
      }

      -- Per-server overrides. These merge over the defaults that nvim-lspconfig
      -- ships (cmd, filetypes, root_markers), and automatic_enable picks them up.
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--header-insertion-decorators",
        },
        -- Pin root resolution to project markers (most-specific first) so clangd
        -- anchors at the project dir, not $HOME. Without this, 0.12's default
        -- fell back to ~ and clangd (plus the diagnostic-picker's .clangd writes)
        -- rooted in the home directory.
        root_markers = {
          "compile_commands.json",
          ".clangd",
          "compile_flags.txt",
          ".git",
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim', 'bufnr' },
            },
            -- The Neovim runtime and plugin libraries come from lazydev.nvim
            -- (below), which adds only what a file actually requires instead
            -- of indexing every installed plugin up front.
            workspace = {
              checkThirdParty = false, -- no "configure your work environment" prompts
            },
            telemetry = { enable = false },
          },
        },
      })

      -- Grammar/spelling for prose only. Out of the box harper checks comments
      -- in every programming language too, which is mostly noise in code.
      vim.lsp.config("harper_ls", {
        filetypes = { "markdown", "text", "gitcommit" },
        settings = {
          ["harper-ls"] = {
            markdown = { IgnoreLinkTitle = true },
            -- Your own words (names, jargon) go in via the code action
            -- "Add to dictionary"; harper keeps them in its user dictionary.
          },
        },
      })

      -- gopls: Mason builds it with `go install`, so it needs the Go toolchain
      -- (go-toolset from AppStream). staticcheck adds the extra analyzers a
      -- separate golangci-lint run would otherwise cover.
      vim.lsp.config("gopls", {
        settings = {
          gopls = {
            staticcheck = true,
            analyses = { unusedparams = true, shadow = true },
          },
        },
      })

      vim.lsp.config("pylsp", {
        settings = {
          pylsp = {
            plugins = {
              pycodestyle = {
                maxLineLength = 140, -- Set maximum line length
              },
            },
          },
        },
      })

      -- cmake-language-server is installed via pipx (on PATH), not mason, so it
      -- isn't in ensure_installed/automatic_enable above. Enable it explicitly.
      -- NOTE: the pipx venv must pin pygls>=1.1.1,<2.0 — pygls 2.x removed the
      -- pygls.server.LanguageServer import this server relies on.
      vim.lsp.enable("cmake")
    end,
  },

  -- LuaSnip configuration
  {
    "L3MON4D3/LuaSnip",
    -- Loaded by nvim-cmp (completion.lua), which lists it as a dependency.
    dependencies = {
      "rafamadriz/friendly-snippets",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },
  -- nvim-lspconfig for setting up LSP servers
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim" },
    lazy = false,
    -- Only supplies the lsp/*.lua server defaults; nothing to set up.
    -- Formatting is conform.nvim's job, keybindings live in the LspAttach
    -- autocmd in lua/config/autocmds.lua.
  },
  -- lua_ls knowledge of the Neovim API (vim.*, vim.uv, plugin modules) when
  -- editing Lua. Successor to the archived neodev.nvim, by the same author.
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        -- libuv types, only for files that use vim.uv
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
}

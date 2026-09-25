-- Language servers: Mason installs them, nvim-lspconfig starts them.
--
-- Neovim 0.8 has no vim.lsp.config()/vim.lsp.enable() (both 0.11+), so servers
-- are set up the older way: require("lspconfig").<server>.setup({...}).
-- What the 0.11 version configured across this file and completion.lua is
-- merged here, per server.

require("mason").setup({
  -- Pin Mason's package registry to one release, like every plugin here. That
  -- makes server versions reproducible, keeps this older Mason (v1.11.0) on a
  -- registry it's known to read, and skips the GitHub API lookup for the
  -- "latest" registry (which fails behind strict proxies and when rate-limited).
  -- To update servers: set a newer tag from
  -- https://github.com/mason-org/mason-registry/releases and run :MasonUpdate.
  registries = { "github:mason-org/mason-registry@2026-09-25-minute-minute" },
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗"
    }
  }
})

-- mason-lspconfig v1: installs the servers on first launch. (v2's
-- automatic_enable needs 0.11; the setup loop below starts them instead.)
require("mason-lspconfig").setup({
  ensure_installed = { 'clangd', 'rust_analyzer', 'bashls', 'lua_ls', 'marksman', 'pylsp', 'jsonls', 'texlab' },
})

-- Non-LSP tooling (linters, formatters) that conform.nvim and nvim-lint shell
-- out to. mason-lspconfig only takes LSP servers, and mason-tool-installer
-- isn't worth another 0.8 pin for a loop this small, so install them straight
-- from the registry: once the registry refreshes, anything missing starts
-- installing in the background.
local tools = {
  -- Formatters (conform.nvim)
  "prettier",      -- javascript, typescript, html, css, json, yaml
  "stylua",        -- lua
  "shfmt",         -- sh, bash
  "black",         -- python
  "isort",         -- python (import sorting)
  "gersemi",       -- cmake
  "taplo",         -- toml
  "latexindent",   -- tex
  "bibtex-tidy",   -- bib

  -- Linters (nvim-lint)
  "shellcheck",    -- sh, bash
  "markdownlint",  -- markdown
  "checkmake",     -- make
  "cmakelint",     -- cmake
  "hadolint",      -- dockerfile
  "yamllint",      -- yaml
  "gitlint",       -- gitcommit

  -- Not available from Mason, installed out of band:
  --   cppcheck         -> dnf (EPEL), c/cpp linting
  --   clang-format     -> dnf (clang-tools-extra)
  --   gofmt, rustfmt   -> ship with the Go / Rust toolchains
}
-- Skipped headless (install.sh, CI), which exits before an install finishes.
if #vim.api.nvim_list_uis() > 0 then
  local registry = require("mason-registry")
  registry.refresh(function()
    for _, name in ipairs(tools) do
      local ok, pkg = pcall(registry.get_package, name)
      if ok and not pkg:is_installed() then
        pkg:install()
      end
    end
  end)
end

-- neodev hooks into lua_ls, so it has to be set up before lua_ls is.
require("neodev").setup({
  library = { plugins = {}, types = true },
})

-- Snippets from friendly-snippets, for LuaSnip.
require("luasnip.loaders.from_vscode").lazy_load()

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local servers = {
  clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "--suggest-missing-includes",
      "--clang-tidy",
      "--header-insertion=iwyu",
      "--header-insertion-decorators",
    },
    -- Pin root resolution to project markers (most-specific first) so clangd
    -- anchors at the project dir, not $HOME (and so do the diagnostic-picker's
    -- .clangd writes).
    root_dir = function(fname)
      return vim.fs.root(fname, { "compile_commands.json", ".clangd", "compile_flags.txt", ".git" })
    end,
    -- Disable clangd's LSP semantic tokens so treesitter highlighting always
    -- wins. (No-op on 0.8, which has no semantic-token support; kept so the
    -- config behaves the same on newer versions.)
    on_attach = function(client, _)
      client.server_capabilities.semanticTokensProvider = nil
    end,
  },

  -- Only use .config/nvim as the workspace for config files.
  lua_ls = {
    root_dir = function(fname)
      local config_dir = vim.fn.stdpath("config")
      if fname:match("^" .. vim.pesc(config_dir)) then
        return config_dir
      end
      return vim.fs.root(fname, { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml", ".git" })
    end,
    settings = {
      Lua = {
        diagnostics = {
          globals = { 'vim', 'bufnr' },
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true), -- include nvim runtime files
          checkThirdParty = false,                           -- avoid unecessary prompts?
        },
        telemetry = { enable = false },
      },
    },
  },

  -- Marksman: pin root to a real vault/project, never $HOME. Default behavior
  -- walks up to $HOME and recurses every .md file under it, which hits
  -- symlink loops in Steam Proton wine prefixes and crashes the server.
  marksman = {
    root_dir = function(fname)
      local home = vim.uv.os_homedir() or os.getenv("HOME")
      local root = vim.fs.root(fname, { ".marksman.toml", ".git", ".obsidian" })
      -- Refuse $HOME (or its parents) as a root; fall back to the file's own
      -- directory so marksman scans nothing else.
      if not root or root == home or #root <= #home then
        root = vim.fs.dirname(fname)
      end
      return root
    end,
  },

  pylsp = {
    settings = {
      pylsp = {
        plugins = {
          pycodestyle = {
            maxLineLength = 140, -- Set maximum line length
          },
        },
      },
    },
  },

  rust_analyzer = {},
  bashls = {},
  jsonls = {},
  texlab = {},

  -- cmake-language-server is installed via pipx (on PATH), not mason.
  -- NOTE: the pipx venv must pin pygls>=1.1.1,<2.0 — pygls 2.x removed the
  -- pygls.server.LanguageServer import this server relies on.
  cmake = {},
}

for name, config in pairs(servers) do
  config.capabilities = capabilities
  lspconfig[name].setup(config)
end

-- LSP keybindings are set in config/autocmds.lua's LspAttach autocmd.
-- Format-on-save is handled by conform.nvim (with lsp_fallback).

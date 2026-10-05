-- ~/.config/nvim/lua/plugins/completion.lua
return {
  {
    "hrsh7th/nvim-cmp",
    lazy = false,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        window = {
          documentation = cmp.config.window.bordered(),
          completion = cmp.config.window.bordered(),
        },
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        -- Highlight the first item as soon as the menu opens, without
        -- inserting it, so <CR>/<C-y> accept exactly what you see. With
        -- nothing pre-selected <CR> only ever made a newline and dropped the
        -- completion. <C-e> closes the menu when you want the newline.
        completion = { completeopt = "menu,menuone,noinsert" },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping({
            i = function(fallback)
              -- selected, not active: noinsert highlights without inserting
              if cmp.visible() and cmp.get_selected_entry() then
                cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
              else
                fallback()
              end
            end,
            s = cmp.mapping.confirm({ select = true }),
            c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false }),
          }),
          ["<C-y>"] = cmp.mapping.confirm({ select = true }),
          -- <Tab>/<S-Tab>: move through the menu while it is open; otherwise
          -- jump between the placeholders of an expanded snippet (LSP
          -- function completions arrive as `f(${1:a}, ${2:b})`); otherwise a
          -- plain Tab.
          ["<Tab>"] = cmp.mapping(function(fallback)
            local luasnip = require("luasnip")
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            local luasnip = require("luasnip")
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          -- require("...") module names while editing Neovim Lua; group 0
          -- so it doesn't hide LSP results.
          { name = "lazydev", group_index = 0 },
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          {
            name = "buffer",
            option = {
              get_bufnrs = function()
                local bufs = {}
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                  bufs[vim.api.nvim_win_get_buf(win)] = true
                end
                return vim.tbl_keys(bufs)
              end,
            }
          },
        }),
      })
      -- Command-line setups
      -- Command lines keep nothing pre-selected: <CR> runs what you typed.
      cmp.setup.cmdline("/", {
        completion = { completeopt = "menu,menuone,noselect" },
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })
      cmp.setup.cmdline(":", {
        completion = { completeopt = "menu,menuone,noselect" },
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" },
          { name = "cmdline", option = { ignore_cmds = { "Man", "!" } } },
        }),
      })
    end,
  },
  {
    "hrsh7th/cmp-nvim-lsp",
    lazy = false,
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Configure lua_ls to only use .config/nvim as workspace for config files
      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local config_dir = vim.fn.stdpath("config")
          -- The buffer may carry the resolved path when ~/.config/nvim is a
          -- symlink into a dotfiles repo (rocky9-dotfiles), so match both.
          local real_dir = vim.fn.resolve(config_dir)
          if fname:match("^" .. vim.pesc(config_dir)) or fname:match("^" .. vim.pesc(real_dir)) then
            on_dir(config_dir)
            return
          end
          on_dir(vim.fs.root(fname, {".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml", ".git"}))
        end,
      })

      -- Marksman: pin root to a real vault/project, never $HOME.
      -- Default behavior walks up to $HOME and recurses every .md file
      -- under it, which hits symlink loops in Steam Proton wine prefixes
      -- (~/.local/share/Steam/.../dosdevices/z: → /) and crashes the server.
      vim.lsp.config("marksman", {
        capabilities = capabilities,
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local home = vim.uv.os_homedir() or os.getenv("HOME")
          local root = vim.fs.root(fname, { ".marksman.toml", ".git", ".obsidian" })
          -- Refuse $HOME (or its parents) as a root; fall back to the
          -- file's own directory so marksman scans nothing else.
          if not root or root == home or #root <= #home then
            root = vim.fs.dirname(fname)
          end
          -- A note directly in $HOME has $HOME as its own directory, too.
          -- Not calling on_dir skips marksman for that buffer.
          if root == home or #root <= #home then
            return
          end
          on_dir(root)
        end,
      })

      local servers = {
        "clangd", "rust_analyzer", "bashls", "lua_ls",
        "marksman", "pylsp", "jsonls", "texlab",
      }
      for _, server in ipairs(servers) do
        if server == "clangd" then
          -- cmd and root_markers live in lsp-config.lua.
          vim.lsp.config(server, {
            capabilities = capabilities,
            -- Disable clangd's LSP semantic tokens so treesitter highlighting
            -- always wins. clangd's semantic highlighting layers on top of
            -- treesitter only after it resolves a file (needs the right
            -- headers / compile_commands.json), which made std::/type colors
            -- inconsistent: foam when resolved, plain when not. Dropping the
            -- provider makes highlighting grammar-based, instant, consistent.
            on_attach = function(client, _)
              client.server_capabilities.semanticTokensProvider = nil
            end,
          })
        elseif server ~= "lua_ls" and server ~= "marksman" then
          vim.lsp.config(server, { capabilities = capabilities })
        end
      end
      vim.lsp.enable(servers)
      -- LSP keybindings (gd, K, <leader>rn, etc.) are defined in the
      -- LspAttach autocmd in lua/config/autocmds.lua, the single source of
      -- truth; a second copy here raced it and K was intermittently narrow.
    end,
  },
}

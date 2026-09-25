-- Diagnostics display + global user autocmds.
-- Required from init.lua AFTER lazy.nvim has loaded plugins, so these win
-- over any plugin that configures vim.diagnostic itself.

local sev = vim.diagnostic.severity
local sign_text = {
  [sev.ERROR] = "✘",
  [sev.WARN] = "⚠",
  [sev.HINT] = "💡",
  [sev.INFO] = "ℹ",
}
vim.diagnostic.config({
  virtual_text = false,
  signs = { text = sign_text },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
-- Before 0.10, diagnostic sign icons come from :sign-define, not signs.text.
if vim.fn.has("nvim-0.10") == 0 then
  local names = { [sev.ERROR] = "Error", [sev.WARN] = "Warn", [sev.HINT] = "Hint", [sev.INFO] = "Info" }
  for s, name in pairs(names) do
    local hl = "DiagnosticSign" .. name
    vim.fn.sign_define(hl, { text = sign_text[s], texthl = hl, numhl = "" })
  end
end

-- Before 0.11, vim.lsp.buf.hover() and signature_help() take no options, so the
-- wide, wrapping, rounded floats used in the LspAttach keymaps below are set
-- on the handlers instead.
if vim.fn.has("nvim-0.11") == 0 then
  local float = { border = "rounded", width = 90, wrap = true }
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, float)
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, float)
end

local augroup = vim.api.nvim_create_augroup
local UserAutoCommands = augroup('UserAutoCommands', {})

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

function R(name)
    require("plenary.reload").reload_module(name)
end

autocmd('TextYankPost', {
    group = yank_group,
    pattern = '*',
    callback = function()
        -- vim.highlight was renamed vim.hl in 0.11 and is on the removal path.
        local hl = vim.hl or vim.highlight
        hl.on_yank({
            higroup = 'IncSearch',
            timeout = 40,
        })
    end,
})

-- Strip trailing whitespace on save.
--   * The modifiable guard is load-bearing: this fires for every :w, and on a
--     non-modifiable buffer (`:checkhealth` output, for one) the substitute
--     raises E21 and the write reports an error.
--   * keeppatterns keeps \s\+$ out of the search register, so n after a save
--     still repeats your own search.
--   * winsaveview/winrestview keep the cursor and scroll position, which a
--     bare %s does not.
autocmd({"BufWritePre"}, {
    group = UserAutoCommands,
    pattern = "*",
    callback = function()
        if not vim.bo.modifiable or vim.bo.readonly then return end
        local view = vim.fn.winsaveview()
        vim.cmd([[keeppatterns %s/\s\+$//e]])
        vim.fn.winrestview(view)
    end,
})

autocmd('LspAttach', {
    group = UserAutoCommands,
    callback = function(e)
        local opts = { buffer = e.buf }
        -- LSP keybindings (buffer-local, only when LSP is attached)
        vim.keymap.set('n', 'gr', '<cmd>Telescope lsp_references<cr>', opts)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        -- Wider, wrapping, bordered hover/signature floats so long declarations
        -- aren't cut off. open_floating_preview IGNORES min_width (verified on
        -- 0.12), so a fixed `width` is the only way to guarantee a comfortable
        -- floor; long content then wraps, short content just has slack. 90 cols
        -- fits most C++ signatures on one or two lines.
        local float = { border = "rounded", width = 90, wrap = true }
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover(float) end, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>ws", vim.lsp.buf.workspace_symbol, opts)
        vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help(float) end, opts)
        vim.keymap.set("n", "<leader>k", function() vim.lsp.buf.signature_help(float) end, opts)
        -- Browse symbols: current file (ds) vs. whole project (dS).
        vim.keymap.set("n", "<leader>ds", "<cmd>Telescope lsp_document_symbols<cr>", opts)
        vim.keymap.set("n", "<leader>dS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", opts)
    end
})
--vim.api.nvim_set_option('wildmode', 'list:longest,full')
--vim.o.wildmode = 'list:longest'

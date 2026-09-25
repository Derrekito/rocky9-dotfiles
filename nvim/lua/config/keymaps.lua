local setkey = vim.keymap.set

vim.g.mapleader = " "

-- Prevent <CR> from doing anything unexpected globally
vim.keymap.set("n", "<CR>", "<nop>", { desc = "Disable default <CR>" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "help",
  callback = function()
    print("Help filetype detected!")
    vim.keymap.set("n", "<CR>", "<C-]>", { buffer = true, desc = "Jump to tag under cursor" })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.keymap.set("n", "<CR>", "<CR>", { buffer = true, desc = "Jump to quickfix item" })
  end,
})


-- Increase font size
setkey("n", "<leader>+", ":hi! Normal guifont+=1<CR>")

-- In visual mode, move the selected block of text one line up or down and
-- reselect the block.
setkey("v", "J", ":m '>+1<CR>gv=gv")
setkey("v", "K", ":m '<-2<CR>gv=gv")

setkey("i", "<C-c>", "<Esc>")

setkey("n", "<leader>pv", vim.cmd.Ex)

-- Join lines without changing the cursor position.
setkey("n", "J", "mzJ`z")

-- Scroll down half a page and center the screen on the cursor.
setkey("n", "<C-d>", "<C-d>zz")

-- Scroll up half a page and center the screen on the cursor.
setkey("n", "<C-u>", "<C-u>zz")

-- Repeat the last search, center the screen on the found item, and reselect
-- the last visual selection.
setkey("n", "n", "nzzzv")

-- Repeat the last search in the opposite direction, center the screen on the
-- found item, and reselect the last visual selection.
setkey("n", "N", "Nzzzv")

-- In Visual mode, replace the selected text with the last yanked text.
-- This binding uses the "black hole" register "_" to delete "d" the selected
-- text without affecting the clipboard or other registers, then pastes "P" the
-- previously yanked text in its place. Useful for quick text swaps.
setkey("x", "<leader>p", [["_dP]])

-- Map <leader>y to copy the current line (in Normal mode) or the selected text
-- (in Visual mode) directly to the system clipboard. This vim.keymap utilizes the
-- "+ register, which is Vim's way of accessing the system clipboard. It allows
-- for easy copying of text from Vim to other applications outside of Vim.
setkey({ "n", "v" }, "<leader>y", [["+y]])

-- In Normal mode, map <leader>Y to copy from the cursor position to the end of
-- the line directly to the system clipboard. This uses the "+ register, which
-- allows for interaction with the system clipboard, facilitating text transfer
-- from Vim to external applications.
setkey("n", "<leader>Y", [["+Y]])

-- Map <leader>d in normal and visual modes to delete without affecting the clipboard.
setkey({ "n", "v" }, "<leader>d", [["_d]])

-- Disable the default functionality of 'Q' in normal mode.
setkey("n", "Q", "<nop>")

-- Map <leader>f in normal mode to format the buffer using the configured LSP.
setkey("n", "<leader>f", vim.lsp.buf.format)

-- Map Ctrl+k in normal mode to go to the next item in the quickfix list and center it on screen.
setkey("n", "<C-k>", "<cmd>cnext<CR>zz")

-- Map Ctrl+j in normal mode to go to the previous item in the quickfix list and center it on screen.
setkey("n", "<C-j>", "<cmd>cprev<CR>zz")

-- Map <leader>k in normal mode to go to the next item in the location list and center it on screen.
setkey("n", "<leader>k", "<cmd>lnext<CR>zz")

-- Map <leader>j in normal mode to go to the previous item in the location list and center it on screen.
setkey("n", "<leader>j", "<cmd>lprev<CR>zz")

-- substitute the word under the cursor throughout the file, case-insensitive
setkey("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
-- substitute the word under the cursor throughout the file, case-sensitive
setkey("n", "<leader>S", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/g<Left><Left><Left>]])
-- make the current file executable using chmod +x
setkey("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

-- source file
--setkey("n", "<leader><leader>", function()
--    vim.cmd("so")
--end)

local function setNetrwKeymap()
  if vim.bo.filetype == "netrw" then
    vim.keymap.set("n", "<leader><leader>", ":TypeAnim<CR>", { buffer = true })
  else
    -- source file
    vim.keymap.set("n", "<leader><leader>", function()
      vim.cmd("so")
    end)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = setNetrwKeymap
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = "*",
  callback = setNetrwKeymap
})
-- Select All
setkey("n", "<C-a>", "gg<S-v>G")

-- Split Window
setkey("n", "<leader>-", ":split<Return>", opts)

-- Vertical split pinned to 81 columns (one past colorcolumn=80). The count
-- prefix sets the *new* window's width; winfixwidth pins it so later splits and
-- <C-w>= redistribute slack to the other (non-fixed) windows instead of
-- squashing this one. Recurses naturally: each new pane is its own 81-col split.
setkey("n", "<leader>|", function()
  vim.cmd("81vsplit")
  vim.wo.winfixwidth = true
end, { desc = "81-col pinned vsplit" })

-- Plain, unpinned vertical split (previous <leader>| behavior).
setkey("n", "<leader>\\", ":vsplit<Return>", opts)

-- Move to Window
setkey("n", "sh", "<C-w>h")
setkey("n", "sk", "<C-w>k")
setkey("n", "sj", "<C-w>j")
setkey("n", "sl", "<C-w>l")


-- Move the current window to the far left of the screen.
setkey("n", "Sh", "<C-w>H")
-- Move the current window to the bottom of the screen.
setkey("n", "Sj", "<C-w>J")
-- Move the current window to the top of the screen.
setkey("n", "Sk", "<C-w>K")
-- Move the current window to the far right of the screen.
setkey("n", "Sl", "<C-w>L")

-- Resize Window
setkey("n", "<C-left>", "<C-w><")
setkey("n", "<C-right>", "<C-w>>")
setkey("n", "<C-up>", "<C-w>+")
setkey("n", "<C-down>", "<C-w>-")

-- Set highlight on search, but clear on pressing <esc> in normal mode
vim.opt.hlsearch = true
setkey("n", "<esc>", ":nohlsearch<CR>")

-- Diagnostic Keymaps
-- vim.diagnostic.goto_next/goto_prev were deprecated in 0.11 for vim.diagnostic.jump.
-- jump() wraps by default (pass wrap=false to disable); direction is set via count.
setkey("n", "<leader>dn", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Go to next diagnostic" })
setkey("n", "<leader>dp", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Go to previous diagnostic" })
setkey("n", "<leader>de", function()
  local _, winid = vim.diagnostic.open_float({ border = "rounded", focusable = true, scope = "line" })
  if not winid then
    vim.diagnostic.jump({ count = 1, float = { border = "rounded" } })
  end
end, { desc = "Show or go to next diagnostic" })
setkey("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics location list" })
-- Populate the quickfix list with all diagnostics and open the quickfix window.
-- Navigate with <C-j>/<C-k> (cprev/cnext).
setkey("n", "<leader>dq", function()
  vim.diagnostic.setqflist()
  vim.cmd("copen")
end, { desc = "Diagnostics -> quickfix + open" })

-- Reload buffer to re-attach LSP without erroring on / discarding unsaved
-- changes. Bare `:edit` raises E37 when the buffer is modified.
local function reload_for_lsp()
  if vim.bo.modified then
    vim.notify("LSP restart: buffer modified, skipping reload (save to re-attach)", vim.log.levels.INFO)
    return
  end
  vim.cmd("edit")
end

-- vim.lsp.stop_client works on every Neovim version. The client:stop() method
-- form is 0.11+; on 0.8 stop is a plain function, and calling it as a method
-- passes the client in as the `force` flag.
setkey("n", "<leader>lr", function()
  for _, client in ipairs(vim.lsp.get_clients()) do
    vim.lsp.stop_client(client.id)
  end
  vim.defer_fn(reload_for_lsp, 500)
end, { desc = "Restart all LSP clients" })

setkey("n", "<leader>lR", function()
  for mod, _ in pairs(package.loaded) do
    if mod:match("^diagnostic%-picker") then
      package.loaded[mod] = nil
    end
  end
  for _, client in ipairs(vim.lsp.get_clients()) do
    vim.lsp.stop_client(client.id)
  end
  vim.defer_fn(reload_for_lsp, 500)
  print("Reloaded diagnostic-picker + restarted LSP")
end, { desc = "Reload diagnostic-picker and restart LSP" })

-- Diagnostic settings picker keybinding moved to lua/plugins/diagnostic-picker.lua

-- Clipboard: OSC 52 for copy always, Wayland/OSC 52 for paste per context.
--   Copy  -> always OSC 52. It lands in the terminal's clipboard whether
--            nvim is local or SSH'd in, so there's nothing to detect. In a
--            long-lived tmux session that gets reattached from both local
--            and remote clients, relying on env vars captured at pane
--            creation was stale and silently broke remote copy.
--   Paste -> stays conditional. Ghostty's OSC 52 *read* policy defaults to
--            "ask" (a real security boundary against escape-sequence
--            clipboard exfiltration from untrusted output), so an
--            unconditional switch would prompt on every local paste. Local
--            sessions keep wl-paste (direct, no prompt); SSH sessions route
--            through OSC 52 paste-back. Requires update-environment in
--            tmux.conf to keep SSH_TTY/SSH_CONNECTION fresh across reattach.
-- Neovim 0.10+ ships vim.ui.clipboard.osc52; on 0.8 use lua/osc52.lua, which
-- copies the same way. Its paste returns the last copy from this Neovim, since
-- 0.8 can't read the terminal's clipboard.
local has_builtin_osc52, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
if not has_builtin_osc52 then
  osc52 = require('osc52')
end
local clipboard = {
  name = 'OSC 52 (copy) + context-aware paste',
  copy = {
    ['+'] = osc52.copy('+'),
    ['*'] = osc52.copy('*'),
  },
}
if vim.env.SSH_TTY or vim.env.SSH_CONNECTION then
  clipboard.paste = {
    ['+'] = osc52.paste('+'),
    ['*'] = osc52.paste('*'),
  }
elseif vim.fn.executable('wl-paste') == 1 then
  -- Same command arrays Nvim's built-in wl-copy provider would have
  -- auto-detected; spelled out here because setting g:clipboard.copy
  -- disables that auto-detection entirely, including for paste.
  clipboard.paste = {
    ['+'] = { 'wl-paste', '--no-newline' },
    ['*'] = { 'wl-paste', '--no-newline', '--primary' },
  }
elseif vim.fn.executable('xclip') == 1 then
  -- X11 session (or no wl-clipboard installed): read with xclip instead.
  clipboard.paste = {
    ['+'] = { 'xclip', '-o', '-selection', 'clipboard' },
    ['*'] = { 'xclip', '-o', '-selection', 'primary' },
  }
else
  clipboard.paste = {
    ['+'] = osc52.paste('+'),
    ['*'] = osc52.paste('*'),
  }
end
-- vim.g.clipboard reads back a copy, not a live reference, so build the
-- table in full above and assign it once here.
vim.g.clipboard = clipboard

-- Route default yanks/pastes through the + register (system clipboard).
-- Backend is whatever the block above resolved to: OSC 52 for copy always,
-- wl-paste locally / OSC 52 over SSH for paste.
vim.opt.clipboard:append('unnamedplus')

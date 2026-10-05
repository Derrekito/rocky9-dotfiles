-- Editor options + option-related autocmds.
--
-- Every autocmd here is in the UserOptions group. The config-reload autocmd at
-- the bottom re-requires this file on each save of a config file; without a
-- cleared group each reload would add another copy of every autocmd,
-- including the reload autocmd itself, so the handlers doubled per save.
local group = vim.api.nvim_create_augroup("UserOptions", { clear = true })

-- Soft wrap is off by default, but when it is turned on (markdown, zen-mode)
-- wrapped lines break at words and keep their indent.
vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.breakindentopt = "shift:2"

vim.opt.cursorline = true
vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.autoindent = true
vim.opt.smartindent = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.fn.mkdir(vim.o.undodir, "p")
vim.opt.undofile = true

-- Highlight matches; <Esc> clears (config.keymaps).
vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.termguicolors = true

-- Suppress the intro/splash screen on argument-less launches
vim.opt.shortmess:append("I")

-- Keep the cursor line vertically centered.
vim.opt.scrolloff = 999
vim.opt.signcolumn = "auto"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "80"

vim.o.conceallevel = 2

-- Makefile tabs
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "make",
  callback = function()
    vim.opt_local.tabstop = 8
    vim.opt_local.shiftwidth = 8
    vim.opt_local.expandtab = false
  end,
})

-- C/C++ indentation: width/tabs come from the buffer's effective
-- .clang-format (see lua/clang-format-indent.lua), so each project gets its
-- own settings instead of a hardcoded 4. This FileType autocmd fires after
-- after/ftplugin, so it is the last word on these options.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "c", "cpp", "cuda" },
  callback = function(args)
    vim.bo[args.buf].expandtab = true
    vim.bo[args.buf].cindent = true
    require("clang-format-indent").apply(args.buf)
  end,
})

-- *.latex files are pandoc templates, not LaTeX documents; the stock
-- detection calls them tex. See after/ftplugin/pandoc-latex.lua.
vim.filetype.add({ extension = { latex = "pandoc-latex" } })

-- Auto-reload files changed outside of Neovim.
-- :checktime raises E11 in the command-line window (q:), and CursorHold
-- fires there every 'updatetime' ms, so skip it in that window.
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  group = group,
  callback = function()
    if vim.fn.getcmdwintype() == "" then
      vim.cmd("checktime")
    end
  end,
})

-- Auto-reload config on save
vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  pattern = vim.fn.stdpath("config") .. "/**/*.lua",
  callback = function()
    local ok, err = pcall(function()
      -- Clear loaded modules. Named explicitly rather than "^config%." so the
      -- telescope helper under config/ isn't dropped mid-picker; autocmds is
      -- safe to re-run because its augroups are created with clear = true.
      for name, _ in pairs(package.loaded) do
        if name:match("^config%.options")
          or name:match("^config%.keymaps")
          or name:match("^config%.autocmds")
          or name:match("^plugins") then
          package.loaded[name] = nil
        end
      end

      -- Reload modules
      require("config.options")
      require("config.keymaps")
      require("config.autocmds")

      -- Only re-trigger FileType for non-lua buffers to avoid LSP restart spam
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
          local ft = vim.bo[buf].filetype
          if ft and ft ~= "" and ft ~= "lua" then
            vim.api.nvim_buf_call(buf, function()
              vim.cmd("doautocmd FileType " .. ft)
            end)
          end
        end
      end
    end)

    if not ok then
      vim.notify("Config reload error: " .. tostring(err), vim.log.levels.ERROR)
    end
  end,
})

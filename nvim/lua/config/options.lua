-- Function to setup smarter indentation with word wrapping
local function setup_smart_indentation_wrapping()
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.breakindent = true
  vim.wo.breakindentopt = "shift:2"
end

-- Call the function to apply settings
setup_smart_indentation_wrapping()

vim.wo.cursorline = true
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
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

-- Suppress the intro/splash screen on argument-less launches
vim.opt.shortmess:append("I")

vim.opt.scrolloff = 8
vim.opt.signcolumn = "auto"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "80"
-- Test change 5 to trigger reload

vim.o.scrolloff = 999

vim.wo.wrap = false

vim.g.mapleader = " "

-- Enable clipboard integration
vim.opt.clipboard:append("unnamedplus")

-- Makefile tabs
vim.api.nvim_create_autocmd("FileType", {
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
  pattern = { "c", "cpp", "h", "hpp" },
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.cindent = true
    require("clang-format-indent").apply()
  end,
})


vim.o.conceallevel = 2

-- Auto-reload files changed outside of Neovim
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  command = "checktime",
})

-- Auto-reload config on save
vim.api.nvim_create_autocmd("BufWritePost", {
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

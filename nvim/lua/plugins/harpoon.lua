-- Harpoon 2 (harpoon2 branch). Its menu passes a title to nvim_open_win,
-- which 0.8 rejects; lua/compat.lua strips it, so the menu just has no title.
local harpoon = require("harpoon")
harpoon:setup({
  settings = {
    save_on_toggle = true, -- persist list edits when the menu closes
  },
})

-- The quick menu's width is ui_width_ratio * editor width (so it grows
-- with the terminal), capped at ui_max_width. height_in_lines bounds height.
local toggle_opts = {
  border = "rounded",
  ui_width_ratio = 0.80,  -- wider than the 0.63 default, for long paths
  ui_max_width = 120,     -- never exceed this many columns
  height_in_lines = 12,
}

-- Keymaps (Harpoon 2 API: harpoon:list() + harpoon.ui).
vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end,
  { desc = "Harpoon: Add file" })
vim.keymap.set("n", "<C-e>", function()
  harpoon.ui:toggle_quick_menu(harpoon:list(), toggle_opts)
end, { desc = "Harpoon: Toggle menu" })

-- Direct jumps to first 4 files. Guard against selecting an empty slot:
-- the default select handler crashes (config.lua: length of nil) when the
-- index holds no item, so no-op (with a hint) instead of erroring.
local function jump(idx)
  return function()
    local list = harpoon:list()
    if list:get(idx) then
      list:select(idx)
    else
      vim.notify("Harpoon: no file in slot " .. idx, vim.log.levels.INFO)
    end
  end
end
vim.keymap.set("n", "<leader>1", jump(1), { desc = "Harpoon: File 1" })
vim.keymap.set("n", "<leader>2", jump(2), { desc = "Harpoon: File 2" })
vim.keymap.set("n", "<leader>3", jump(3), { desc = "Harpoon: File 3" })
vim.keymap.set("n", "<leader>4", jump(4), { desc = "Harpoon: File 4" })

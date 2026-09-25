local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local data = require("cheatsheet.data")

local M = {}

function M.create_picker(title, entries, on_select)
  pickers.new({}, {
    prompt_title = title,
    finder = finders.new_table({
      results = entries,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        on_select(selection.value)
      end)
      return true
    end,
  }):find()
end

function M.show_categories()
  local categories = {}
  for _, section in ipairs(data.sections) do
    table.insert(categories, section.category)
  end
  table.sort(categories)
  M.create_picker("Neovim Shortcuts", categories, function(selected_category)
    M.show_items(selected_category)
  end)
end

function M.show_items(category)
  for _, section in ipairs(data.sections) do
    if section.category == category then
      local items = vim.list_extend(vim.list_extend({}, section.items), { "Back" })
      M.create_picker(category, items, function(selected_item)
        if selected_item == "Back" then
          M.show_categories()
        end
      end)
      return
    end
  end
end

function M.open_cheatsheet()
  M.show_categories()
end

return M

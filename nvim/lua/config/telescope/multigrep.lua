local M = {}

-- Build the ripgrep argv for a prompt. Two spaces split the search pattern
-- from a glob: "foo  *.lua" searches for foo in lua files only. Returns nil
-- for an empty prompt so the finder runs nothing.
function M.build_command(prompt)
  if not prompt or prompt == "" then
    return nil
  end

  local pieces = vim.split(prompt, "  ") -- split if two spaces
  local args = { "rg" }                  -- ripgrep

  if pieces[1] then
    table.insert(args, "-e") -- tells ripgrep that this is the thing we're looking for
    table.insert(args, pieces[1])
  end

  if pieces[2] then -- stuff after the double space
    table.insert(args, "-g")
    table.insert(args, pieces[2])
  end

  return vim.list_extend(args, {
    "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case",
  })
end

M.live_multigrep = function(opts)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local make_entry = require "telescope.make_entry"
  local conf = require "telescope.config".values

  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd() -- get current working directory

  local finder = finders.new_async_job {
    command_generator = M.build_command,
    entry_maker = make_entry.gen_from_vimgrep(opts),
    cwd = opts.cwd, -- pass current working directory
  }
  pickers.new(opts, {
    debounce = 100, -- let me type for a sec
    prompt_title = "Multi Grep",
    finder = finder,
    previewer = conf.grep_previewer(opts),
    sorter = require("telescope.sorters").empty(), -- dont sort, ripgrep already does
  }):find()
end

return M

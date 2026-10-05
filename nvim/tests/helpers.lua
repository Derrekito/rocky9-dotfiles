-- Shared helpers for specs. Load with:
--   local H = dofile(vim.fn.stdpath("config") .. "/tests/helpers.lua")
local H = {}

H.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

-- Record every vim.notify call until the returned stop() is called.
-- Returns the list of { msg, level } and the stop function.
function H.capture_notify()
  local seen = {}
  local orig = vim.notify
  vim.notify = function(msg, level, opts)
    table.insert(seen, { msg = tostring(msg), level = level or vim.log.levels.INFO })
    return orig(msg, level, opts)
  end
  return seen, function() vim.notify = orig end
end

-- Notifications at WARN or above, formatted for an assertion message.
function H.problems(seen, min_level)
  min_level = min_level or vim.log.levels.WARN
  local out = {}
  for _, n in ipairs(seen) do
    if n.level >= min_level then
      table.insert(out, n.msg)
    end
  end
  return out
end

-- Error lines in :messages. Errors swallowed by `silent!` never get there
-- (though they do set v:errmsg, which is why that isn't checked: Neovim's
-- own runtime files use silent! liberally).
function H.message_errors()
  local out = {}
  for _, line in ipairs(vim.split(vim.fn.execute("messages"), "\n")) do
    if line:match("E%d+:") or line:match("^Error") or line:match("stack traceback") then
      table.insert(out, line)
    end
  end
  return out
end

-- Run fn and fail if it raised, printed an error, or notified at ERROR
-- level. Waits `wait` ms (default 50) first so errors from scheduled and
-- deferred callbacks are caught too.
function H.no_errors(fn, wait)
  local seen, stop = H.capture_notify()
  vim.cmd("messages clear")
  local ok, err = pcall(fn)
  vim.wait(wait or 50)
  stop()
  assert(ok, "raised: " .. tostring(err))
  local printed = H.message_errors()
  assert(#printed == 0, "printed errors:\n" .. table.concat(printed, "\n"))
  local errors = H.problems(seen, vim.log.levels.ERROR)
  assert(#errors == 0, "error notifications:\n" .. table.concat(errors, "\n"))
end

-- A fresh temp directory per call, removed at exit.
function H.tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

-- Write `lines` to `dir/name` and return the full path.
function H.write(dir, name, lines)
  local path = dir .. "/" .. name
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines or {}, path)
  return path
end

-- maparg() dict for a mapping, or nil. Accepts <leader> notation. Looks at
-- buffer-local maps of the current buffer first, the same as Neovim does.
function H.map(mode, lhs)
  local m = vim.fn.maparg(lhs, mode, false, true)
  if vim.tbl_isempty(m) then
    return nil
  end
  return m
end

-- Global (non-buffer) maps of `mode`, keyed by lhs.
function H.global_maps(mode)
  local out = {}
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    out[m.lhs] = m
  end
  return out
end

-- Load lazy plugins by name, as their trigger would. Needed before calling
-- a lazy-loaded plugin's keymap callback directly: until the plugin loads,
-- the mapping is lazy.nvim's stub, which only replays the keys. Without
-- lazy.nvim (rocky9-dotfiles' pinned packages) everything is already loaded.
function H.load(...)
  local ok, lazy = pcall(require, "lazy")
  if ok then lazy.load({ plugins = { ... } }) end
end

-- Is lazy.nvim managing plugins (vs. plain packages loaded at startup)?
function H.has_lazy()
  return (pcall(require, "lazy.core.config"))
end

-- Close every window but one and wipe all buffers, so specs don't see
-- each other's state.
function H.reset()
  pcall(vim.cmd, "silent! only!")
  pcall(vim.cmd, "silent! %bwipeout!")
end

return H

-- Resize 'guifont' for GUI frontends (Neovide and friends).
local M = {}

-- Return `guifont` with every `:h<size>` changed by `delta`, or nil when
-- there is no size to change. Sizes may be fractional ("Iosevka:h12.5") and
-- never drop below 1.
function M.bump(guifont, delta)
  if not guifont or not guifont:find(":h%d") then
    return nil
  end
  return (guifont:gsub(":h(%d+%.?%d*)", function(size)
    local new = math.max(1, tonumber(size) + delta)
    return ":h" .. (new == math.floor(new) and ("%d"):format(new) or tostring(new))
  end))
end

function M.increase(delta)
  local new = M.bump(vim.o.guifont, delta or 1)
  if not new then
    vim.notify("guifont has no :h<size> to change (terminal UIs ignore it)", vim.log.levels.INFO)
    return
  end
  vim.o.guifont = new
end

return M

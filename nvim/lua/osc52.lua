-- OSC 52 clipboard for Neovim < 0.10, which predates the built-in
-- vim.ui.clipboard.osc52. Same shape as the built-in: copy(reg) and paste(reg)
-- return functions for vim.g.clipboard.
--
-- Copy writes the OSC 52 escape to the terminal, so it reaches your local
-- clipboard over SSH and through tmux (tmux needs `set -s set-clipboard on`,
-- which your tmux.conf already has).
--
-- Paste cannot ask the terminal for its clipboard on 0.8, so it returns the
-- last thing copied from this Neovim. p/P still work inside Neovim; to paste
-- from other programs, use your terminal's paste key.

local M = {}

local bit = require("bit")
local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = s:byte(i, i + 2)
    local n = bit.bor(bit.lshift(a, 16), bit.lshift(b or 0, 8), c or 0)
    for j = 0, 3 do
      if j <= 1 or (j == 2 and b) or (j == 3 and c) then
        local idx = bit.band(bit.rshift(n, 18 - 6 * j), 63) + 1
        out[#out + 1] = chars:sub(idx, idx)
      else
        out[#out + 1] = "="
      end
    end
  end
  return table.concat(out)
end
M._base64 = base64

local cache = {}

function M.copy(reg)
  local target = reg == "+" and "c" or "s"
  return function(lines, regtype)
    cache[reg] = { lines, regtype }
    local seq = string.format("\027]52;%s;%s\007", target, base64(table.concat(lines, "\n")))
    vim.fn.chansend(vim.v.stderr, seq)
  end
end

function M.paste(reg)
  return function()
    local c = cache[reg]
    if c then
      return c
    end
    return { vim.fn.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') }
  end
end

return M

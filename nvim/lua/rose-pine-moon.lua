-- ~/.config/nvim/lua/rose-pine-moon.lua
-- Shared rose-pine MOON palette + semantic roles.
-- Single source of truth for the moon colors used across colors.lua,
-- render-markdown.lua, and pandoc-latex.lua. Base theme is still the
-- upstream rose-pine/neovim plugin; this only centralizes the hexes
-- we reference by hand.
local M = {}

-- Canonical rose-pine MOON palette
-- (https://rosepinetheme.com/palette/ingredients/ -> Moon)
M.palette = {
  base           = "#232136",
  surface        = "#2a273f",
  overlay        = "#393552",
  muted          = "#6e6a86",
  subtle         = "#908caa",
  text           = "#e0def4",
  love           = "#eb6f92",
  gold           = "#f6c177",
  rose           = "#ea9a97",
  pine           = "#3e8fb0",
  foam           = "#9ccfd8",
  iris           = "#c4a7e7",
  highlight_low  = "#2a283e",
  highlight_med  = "#44415a",
  highlight_high = "#56526e",
}

-- Shared semantic roles: the meanings that recur across more than one file.
-- File-specific semantics (e.g. pandoc variable/loop) stay local to their file.
local p = M.palette
M.roles = {
  error   = p.love,
  info    = p.foam,
  hint    = p.iris,
  warn    = p.gold,
  success = p.pine,
  headings = {
    h1 = p.iris,
    h2 = p.foam,
    h3 = p.rose,
    h4 = p.gold,
    h5 = p.pine,
    h6 = p.foam,
  },
}

return M

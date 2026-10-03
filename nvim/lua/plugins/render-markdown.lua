-- render-markdown.nvim v3.3.1, the last release that runs on Neovim 0.8 (with
-- two aliases from compat.lua). Newer releases need 0.9/0.10, so this is the
-- simpler v3 option set: headings get full-width bars rather than blocks, and
-- there is no per-language icon on code blocks.
local p = require("rose-pine-moon").palette

-- Accent blended ~18% into the base: tinted heading bars that stay quiet.
local function blend(fg, bg, a)
  local function ch(hex, i) return tonumber(hex:sub(i, i + 1), 16) end
  local out = "#"
  for _, i in ipairs({ 2, 4, 6 }) do
    out = out .. string.format("%02x", math.floor(ch(fg, i) * a + ch(bg, i) * (1 - a) + 0.5))
  end
  return out
end

local function apply_highlights()
  local function hl(group, def) vim.api.nvim_set_hl(0, group, def) end
  for i, c in ipairs({ p.iris, p.foam, p.rose, p.gold, p.pine, p.subtle }) do
    hl("RenderMarkdownH" .. i .. "Bg", { bg = blend(c, p.base, 0.18) })
    hl("RenderMarkdownH" .. i, { fg = c, bold = true })
  end
  hl("RenderMarkdownCode", { bg = p.surface })
  hl("RenderMarkdownCodeInline", { bg = p.overlay, fg = p.rose })
  hl("RenderMarkdownBullet", { fg = p.rose })
  hl("RenderMarkdownChecked", { fg = p.foam })
  hl("RenderMarkdownUnchecked", { fg = p.muted })
  hl("RenderMarkdownTodo", { fg = p.gold })
  hl("RenderMarkdownQuote", { fg = p.iris })
  hl("RenderMarkdownDash", { fg = p.highlight_med })
  hl("RenderMarkdownTableHead", { fg = p.iris, bold = true })
  hl("RenderMarkdownTableRow", { fg = p.text })
  hl("RenderMarkdownInfo", { fg = p.foam, bold = true })
  hl("RenderMarkdownSuccess", { fg = p.pine, bold = true })
  hl("RenderMarkdownHint", { fg = p.iris, bold = true })
  hl("RenderMarkdownWarn", { fg = p.gold, bold = true })
  hl("RenderMarkdownError", { fg = p.love, bold = true })
end

require("render-markdown").setup({
  -- LaTeX rendering shells out to latex2text (pylatexenc), which Rocky
  -- doesn't ship; leave math as text.
  latex_enabled = false,
  -- Insert mode stays raw, so the whole buffer shows plain markdown there.
  render_modes = { "n", "c" },
  -- Overlaid on the "# " marker, so each must be exactly two cells wide.
  headings = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
  dash = "─",
  bullets = { "●", "○", "◆", "◇" },
  checkbox = {
    unchecked = "󰄱 ",
    checked = "󰱒 ",
    custom = {
      todo = { raw = "[~]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
    },
  },
  quote = "▍",
  callout = {
    note = "󰋽 Note",
    tip = "󰌶 Tip",
    important = "󰅾 Important",
    warning = "󰀪 Warning",
    caution = "󰳦 Caution",
  },
  -- Unrendered (insert mode, or source mode via <leader>mt) shows the raw
  -- text in full; rendered hides the markup entirely.
  win_options = {
    conceallevel = { default = 0, rendered = 3 },
  },
  code_style = "full",
  table_style = "full",
  cell_style = "overlay",
  highlights = {
    heading = {
      backgrounds = { "RenderMarkdownH1Bg", "RenderMarkdownH2Bg", "RenderMarkdownH3Bg",
        "RenderMarkdownH4Bg", "RenderMarkdownH5Bg", "RenderMarkdownH6Bg" },
      foregrounds = { "RenderMarkdownH1", "RenderMarkdownH2", "RenderMarkdownH3",
        "RenderMarkdownH4", "RenderMarkdownH5", "RenderMarkdownH6" },
    },
    dash = "RenderMarkdownDash",
    code = "RenderMarkdownCode",
    bullet = "RenderMarkdownBullet",
    checkbox = {
      unchecked = "RenderMarkdownUnchecked",
      checked = "RenderMarkdownChecked",
    },
    table = {
      head = "RenderMarkdownTableHead",
      row = "RenderMarkdownTableRow",
    },
    quote = "RenderMarkdownQuote",
    callout = {
      note = "RenderMarkdownInfo",
      tip = "RenderMarkdownSuccess",
      important = "RenderMarkdownHint",
      warning = "RenderMarkdownWarn",
      caution = "RenderMarkdownError",
    },
  },
})

-- render-markdown redraws on WinResized, which Neovim 0.8 doesn't have (see
-- compat.lua); redraw visible markdown on VimResized instead, so full-width
-- elements (heading bars, dashes) follow a terminal resize.
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("UserRenderMarkdownResize", { clear = true }),
  callback = function()
    local ui = require("render-markdown.ui")
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "markdown" then
        ui.schedule_refresh(buf)
      end
    end
  end,
})

apply_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("UserRenderMarkdownColors", { clear = true }),
  callback = apply_highlights,
})

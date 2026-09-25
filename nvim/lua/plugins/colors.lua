-- rose-pine/neovim colorscheme (moon), with local syntax-color overrides.
require('rose-pine').setup({
  variant = 'moon',
  dark_variant = 'main',
  bold_vert_split = false,
  dim_nc_background = false,
  disable_background = false,
  disable_float_background = false,
  disable_italics = false,
  groups = {
    background = 'base',
    background_nc = '_experimental_nc', -- For inactive panes
    panel = 'surface',
    panel_nc = 'base',
    border = 'highlight_med',
    comment = 'muted',
    link = 'iris',
    punctuation = 'subtle',
    error = 'love',
    hint = 'iris',
    info = 'foam',
    warn = 'gold',
    headings = {
      h1 = 'iris',
      h2 = 'foam',
      h3 = 'rose',
      h4 = 'gold',
      h5 = 'pine',
      h6 = 'foam',
    },
  },
  highlight_groups = {
    ColorColumn = { bg = 'love', blend = 1 },
    CursorLine = { bg = 'foam', blend = 1 },
    StatusLine = { fg = 'love', bg = 'love', blend = 10 },
    Search = { bg = 'gold', inherit = false },
    -- Make inactive window background darker
    -- NormalNC = { bg = "#1a1826" },  -- Darker for inactive panes
    NormalNC = { bg = "#1f1d2e" }, -- darker than moon base (this is main's base); intentional off-palette

    -- More syntax color. Types/builtins (@type, @type.builtin) are
    -- already foam. Color the rest so nothing important falls back to
    -- the dim subtle/operator color.
    --   namespace (std) ...... iris   #c4a7e7
    --   function calls ....... rose   #ea9a97
    --   variables (cout, x) .. text   #e0def4 (plain light, NOT subtle —
    --     subtle collides with operators/punctuation like << and ::)
    --   builtin types ........ foam (explicit, in case theme dims it)
    ['@module']           = { fg = 'iris' },
    ['@module.builtin']   = { fg = 'iris', bold = true },
    ['@namespace']        = { fg = 'iris' },
    ['@function.call']    = { fg = 'rose' },
    ['@function.method.call'] = { fg = 'rose' },
    ['@variable']         = { fg = 'text' },   -- readable, distinct from ops
    ['@variable.member']  = { fg = 'foam' },
    -- Types: muted pine instead of loud foam. No bold (quieter).
    ['@type']             = { fg = 'pine' },
    ['@type.builtin']     = { fg = 'pine' },
    -- Same colors under the older capture names that nvim-treesitter v0.8.5.2
    -- (the last version for Neovim 0.8) still uses: members were @field and
    -- method calls were @method.call. Harmless on newer versions.
    ['@field']            = { fg = 'foam' },
    ['@method.call']      = { fg = 'rose' },
  }
})
vim.cmd('colorscheme rose-pine')

return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    completions = { lsp = { enabled = true } },

    -- Unrendered (insert mode, or source mode via <leader>mt) shows the raw
    -- text in full; rendered hides the markup entirely.
    win_options = {
      conceallevel = { default = 0, rendered = 3 },
    },

    -- Render in visual modes too (insert stays raw: it's not listed, so the
    -- whole buffer shows plain markdown there — preferred for editing).
    render_modes = { "n", "c", "t", "v", "V", "\22" },

    anti_conceal = {
      -- Never reveal the cursor line's raw text in rendered modes (normal,
      -- visual, ...); raw editing belongs to insert mode, where the whole
      -- buffer shows plain markdown anyway.
      enabled = false,
    },

    heading = {
      enabled = true,
      sign = false,
      position = "inline",
      icons = { "󰲡  ", "󰲣  ", "󰲥  ", "󰲧  ", "󰲩  ", "󰲫  " },
      width = "block",
      left_pad = 1,
      right_pad = 3,
      min_width = 0,
      -- Thin half-block rule above/below the top two levels only.
      border = { true, true, false, false, false, false },
      border_virtual = true,
      backgrounds = {
        "RenderMarkdownH1Bg",
        "RenderMarkdownH2Bg",
        "RenderMarkdownH3Bg",
        "RenderMarkdownH4Bg",
        "RenderMarkdownH5Bg",
        "RenderMarkdownH6Bg",
      },
      foregrounds = {
        "RenderMarkdownH1",
        "RenderMarkdownH2",
        "RenderMarkdownH3",
        "RenderMarkdownH4",
        "RenderMarkdownH5",
        "RenderMarkdownH6",
      },
    },

    code = {
      enabled = true,
      sign = false,
      style = "full",
      position = "right",
      -- snacks.image draws these as the diagram itself (plugins/snacks.lua);
      -- a code-block frame around a concealed block just bleeds through.
      disable = { "mermaid" },
      language_icon = true,
      language_name = true,
      -- One quiet color for the language label instead of devicons' per-
      -- language colors (python yellow, yaml red, ...).
      highlight_language = "RenderMarkdownCodeInfo",
      width = "block",
      min_width = 60,
      left_pad = 2,
      right_pad = 2,
      border = "thin",
      highlight = "RenderMarkdownCode",
      highlight_inline = "RenderMarkdownCodeInline",
      inline_pad = 1,
    },

    bullet = {
      enabled = true,
      icons = { "●", "○", "◆", "◇" },
      right_pad = 1,
    },

    checkbox = {
      enabled = true,
      position = "overlay",
      unchecked = { icon = "󰄱 ", highlight = "RenderMarkdownUnchecked" },
      checked   = { icon = "󰱒 ", highlight = "RenderMarkdownChecked", scope_highlight = "RenderMarkdownCheckedText" },
      custom = {
        todo = { raw = "[~]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
      },
    },

    quote = {
      enabled = true,
      icon = "▍",
      repeat_linebreak = true,
      highlight = "RenderMarkdownQuote",
    },

    pipe_table = {
      enabled = true,
      style = "full",
      cell = "padded",
      alignment_indicator = "┄",
      border = {
        "╭", "┬", "╮",
        "├", "┼", "┤",
        "╰", "┴", "╯",
        "│", "─",
      },
      head = "RenderMarkdownTableHead",
      row = "RenderMarkdownTableRow",
      filler = "RenderMarkdownTableFill",
    },

    callout = {
      note      = { raw = "[!NOTE]",      rendered = "󰋽 Note",      highlight = "RenderMarkdownInfo" },
      tip       = { raw = "[!TIP]",       rendered = "󰌶 Tip",       highlight = "RenderMarkdownSuccess" },
      important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
      warning   = { raw = "[!WARNING]",   rendered = "󰀪 Warning",   highlight = "RenderMarkdownWarn" },
      caution   = { raw = "[!CAUTION]",   rendered = "󰳦 Caution",   highlight = "RenderMarkdownError" },
    },

    link = {
      enabled = true,
      image = "󰥶 ",
      hyperlink = "󰌹 ",
      highlight = "RenderMarkdownLink",
      custom = {
        web    = { pattern = "^http",                   icon = "󰖟 " },
        github = { pattern = "github%.com",             icon = "󰊤 " },
        youtube = { pattern = "youtube%.com",           icon = "󰗃 " },
        wiki   = { pattern = "wikipedia%.org",          icon = "󰖬 " },
      },
    },

    -- Math is typeset by snacks.image (real LaTeX via pdflatex, shown as an
    -- image in place of the source); the text approximation here would
    -- render it a second time.
    latex = { enabled = false },

    dash = {
      enabled = true,
      icon = "─",
      width = "full",
      highlight = "RenderMarkdownDash",
    },
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)

    local function apply_highlights()
      local function hl(group, def) vim.api.nvim_set_hl(0, group, def) end

      -- Rose-pine moon palette (shared source of truth)
      local p = require("rose-pine-moon").palette

      -- Heading bars: each accent blended ~18% into the base, so the bar is
      -- tinted but quiet and the bold accent text carries the level.
      local function blend(fg, bg, a)
        local function ch(hex, i) return tonumber(hex:sub(i, i + 1), 16) end
        local out = "#"
        for _, i in ipairs({ 2, 4, 6 }) do
          out = out .. string.format("%02x", math.floor(ch(fg, i) * a + ch(bg, i) * (1 - a) + 0.5))
        end
        return out
      end
      local accents = { p.iris, p.foam, p.rose, p.gold, p.pine, p.subtle }
      for i, c in ipairs(accents) do
        hl("RenderMarkdownH" .. i .. "Bg", { bg = blend(c, p.base, 0.18) })
      end

      hl("RenderMarkdownH1", { fg = p.iris, bold = true })
      hl("RenderMarkdownH2", { fg = p.foam, bold = true })
      hl("RenderMarkdownH3", { fg = p.rose, bold = true })
      hl("RenderMarkdownH4", { fg = p.gold, bold = true })
      hl("RenderMarkdownH5", { fg = p.pine, bold = true })
      hl("RenderMarkdownH6", { fg = p.subtle, bold = true })

      hl("RenderMarkdownCode",       { bg = p.surface })
      hl("RenderMarkdownCodeBorder", { bg = p.surface })
      hl("RenderMarkdownCodeInfo",   { fg = p.subtle, bg = p.surface, italic = true })
      hl("RenderMarkdownCodeInline", { bg = p.overlay, fg = p.rose })

      hl("RenderMarkdownChecked",   { fg = p.foam })
      hl("RenderMarkdownUnchecked", { fg = p.muted })
      hl("RenderMarkdownTodo",      { fg = p.gold })
      hl("RenderMarkdownCheckedText", { fg = p.muted, strikethrough = true })

      hl("RenderMarkdownQuote", { fg = p.iris })
      hl("RenderMarkdownLink",  { fg = p.foam, underline = true })
      hl("RenderMarkdownDash",  { fg = p.highlight_med })

      hl("RenderMarkdownTableHead", { fg = p.iris, bold = true })
      hl("RenderMarkdownTableRow",  { fg = p.text })
      hl("RenderMarkdownTableFill", { fg = p.highlight_med })

      hl("RenderMarkdownInfo",    { fg = p.foam, bold = true })
      hl("RenderMarkdownSuccess", { fg = p.pine, bold = true })
      hl("RenderMarkdownHint",    { fg = p.iris, bold = true })
      hl("RenderMarkdownWarn",    { fg = p.gold, bold = true })
      hl("RenderMarkdownError",   { fg = p.love, bold = true })
    end

    apply_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = apply_highlights,
    })
  end,
}

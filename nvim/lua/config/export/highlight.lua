-- Rose-pine moon syntax theme for pandoc's built-in highlighter (slides).
-- Pandoc's stock styles are for light pages; on the dark Beamer theme some
-- tokens (e.g. `True`) all but disappear.
local M = {}

-- Write the theme JSON into `dir`; returns its path.
function M.theme(dir)
  local p = require("rose-pine-moon").palette
  local function c(fg, extra)
    return vim.tbl_extend("force", { ["text-color"] = fg, ["background-color"] = vim.NIL,
      bold = false, italic = false, underline = false }, extra or {})
  end
  local theme = {
    ["text-color"] = p.text,
    ["background-color"] = p.surface,
    ["line-number-color"] = p.muted,
    ["line-number-background-color"] = vim.NIL,
    ["text-styles"] = {
      Keyword = c(p.pine), ControlFlow = c(p.pine), Import = c(p.pine), Preprocessor = c(p.iris),
      DataType = c(p.foam), Function = c(p.rose), BuiltIn = c(p.love), Extension = c(p.iris),
      Variable = c(p.text), Attribute = c(p.iris), Operator = c(p.subtle), Other = c(p.text),
      String = c(p.gold), VerbatimString = c(p.gold), SpecialString = c(p.gold), Char = c(p.gold),
      SpecialChar = c(p.foam), DecVal = c(p.gold), BaseN = c(p.gold), Float = c(p.gold), Constant = c(p.rose),
      Comment = c(p.muted, { italic = true }), Documentation = c(p.muted, { italic = true }),
      CommentVar = c(p.subtle, { italic = true }), Annotation = c(p.subtle, { italic = true }),
      Information = c(p.foam), Warning = c(p.gold), Alert = c(p.love, { bold = true }),
      Error = c(p.love, { bold = true }), RegionMarker = c(p.muted),
    },
  }
  vim.fn.mkdir(dir, "p")
  local path = vim.fs.joinpath(dir, "rose-pine-moon.theme")
  vim.fn.writefile({ vim.json.encode(theme) }, path)
  return path
end

return M

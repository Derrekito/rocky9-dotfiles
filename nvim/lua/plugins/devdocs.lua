-- devdocs.nvim: offline reference docs (cppreference C++23, C, Lua,
-- Bash, CMake, Python) converted to real markdown. gK looks up the symbol
-- under the cursor; :Devdocs browses/searches; :DevdocsUpdate refreshes.
-- Runs on 0.8 through lua/compat.lua (vim.system, vim.spairs, float titles).
require("devdocs").setup({
  viewer = "markdown", -- rendered markdown pages (alternative: "man")
  split = "right",     -- docs open to the right; code frame stays pinned at `width`
  pin = true,          -- hold the code frame at `width` cols; docs get the rest
  -- Added to the plugin's defaults (cpp, c, lua, bash, cmake, python).
  -- :DevdocsUpdate go fetches it.
  docsets = { go = { slug = "go", lang = "go" } },
  filetypes = { go = "go" },
  keyword_chars = { go = "." }, -- gK on fmt.Println looks up the whole name
})

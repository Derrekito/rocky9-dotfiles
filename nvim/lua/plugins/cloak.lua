return {
  "laytan/cloak.nvim",
  -- Before the buffer is shown, so secrets are never drawn uncloaked.
  -- Same file names as file_pattern below.
  event = {
    "BufReadPre .env*", "BufNewFile .env*",
    "BufReadPre wrangler.toml", "BufNewFile wrangler.toml",
    "BufReadPre .dev.vars", "BufNewFile .dev.vars",
  },
  config = function()
    require("cloak").setup({
      enabled = true,
      cloak_character = "*",
      highlight_group = "Comment",
      patterns = {
        {
          -- Match any file starting with ".env"
          -- This can be a table to match multiple file patters.
          file_pattern = {
            ".env*",
            "wrangler.toml",
            ".dev.vars",
          },
          -- Match an equals sign and any character after it.
          -- This can also be a table of patterns to cloak,
          -- exmaple: cloak_pattern = { ":.+", "-.+" } for yaml files.
          cloak_pattern = "=.+"
        },
      },
    })
  end
}

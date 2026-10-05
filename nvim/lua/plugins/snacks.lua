-- snacks.nvim, image module only: renders ```mermaid blocks (via mmdc), image
-- links and $math$ (via pdflatex) as real images inline in markdown buffers.
-- Uses the kitty graphics protocol (Ghostty), and works inside tmux as long as
-- tmux has `allow-passthrough on`.

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    image = {
      enabled = true,
      doc = {
        inline = true,
        max_width = 80,
        max_height = 30,
        -- Diagrams and math replace their source while rendered (the source
        -- reappears when the cursor enters it); plain images render below
        -- their link.
        conceal = function(_, type)
          return type == "math" or type == "chart"
        end,
      },
      convert = {
        mermaid = function()
          return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-c", require("config.markdown").mermaid_config(), "-s", "{scale}" }
        end,
      },
    },
  },
  config = function(_, opts)
    require("snacks").setup(opts)

    -- Source mode (see lua/config/markdown.lua) needs to hide a buffer's
    -- images, but snacks has no per-buffer off switch. Its inline renderer
    -- re-scans via doc.find() on every update and closes any placement that
    -- is no longer found, so reporting "no images" for a source-mode buffer
    -- is enough to make them go away, and dropping the flag brings them back.
    local doc = require("snacks.image.doc")
    local find = doc.find
    doc.find = function(buf, cb, o)
      if vim.b[buf].markdown_source_mode then
        return cb({})
      end
      return find(buf, cb, o)
    end
  end,
}

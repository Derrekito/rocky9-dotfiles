-- Paste a clipboard image into a markdown note: saved under attachments/
-- beside the note (snacks.image then shows it inline), link inserted at the
-- cursor. Uses wl-paste on Wayland.
return {
  "HakonHarnes/img-clip.nvim",
  ft = { "markdown" },
  keys = {
    { "<leader>mI", "<cmd>PasteImage<cr>", ft = "markdown", desc = "Markdown: paste image from clipboard" },
  },
  opts = {
    default = {
      dir_path = "attachments",
      relative_to_current_file = true,
      prompt_for_file_name = true,
      file_name = "%Y-%m-%d-%H%M%S",
      use_absolute_path = false,
    },
    filetypes = {
      markdown = {
        url_encode_path = true,
        template = "![$CURSOR]($FILE_PATH)",
      },
    },
  },
}

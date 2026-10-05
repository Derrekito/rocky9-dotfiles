-- diagnostic-picker.nvim plugin configuration
return {
  "Derrekito/diagnostic-picker.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    -- setup() applies the saved filter through apply_config(), which prints
    -- "Diagnostic filter applied ..." (meant for the picker's <CR>). Here
    -- plugins load at startup rather than on <leader>dg, so it would print
    -- on every launch; keep setup quiet.
    local print_ = print
    print = function() end
    local ok, err = pcall(require("diagnostic-picker").setup, {
      debug = false,
      debug_file = "/tmp/diagnostic-picker-debug.log",
      severities = {
        ERROR = true,
        WARN  = true,
        INFO  = true,
        HINT  = true,
      },
    })
    print = print_
    if not ok then error(err) end
  end,
  keys = {
    {
      "<leader>dg",
      function()
        require("diagnostic-picker").show()
      end,
      desc = "Diagnostic settings",
    },
  },
}

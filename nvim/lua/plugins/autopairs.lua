-- nvim-autopairs - auto-insert matching ), ], }, ", ' as you type
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  config = function()
    local npairs = require("nvim-autopairs")
    npairs.setup({
      check_ts = true,        -- use treesitter to avoid pairing in strings/comments
      fast_wrap = {},         -- enable fast-wrap (default <M-e>)
    })

    -- Insert ( after a completion that is a function/method (nvim-cmp integration)
    local ok, cmp = pcall(require, "cmp")
    if ok then
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end
  end,
}

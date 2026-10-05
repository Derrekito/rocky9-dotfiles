return {
  'Derrekito/nvim-type-anim',
  cmd = { "TypeAnim", "TypeAnimToggle", "TypeAnimKill" },
  keys = { "<leader>ta" },
  config = function()
    require("type-anim").setup({
      -- Not bare <space>: that is <leader>, and binding it made every
      -- leader press that paused start the animation.
      AnimToggleKey = "<leader>ta",
      AnimKillKey = "<C-C>"
    })
  end
}

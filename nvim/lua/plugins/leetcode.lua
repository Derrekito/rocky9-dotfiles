-- leetcode.nvim: solve LeetCode problems inside Neovim — problem list,
-- description split, editable solution buffer, run official tests and
-- submit without leaving the editor. clangd/gK/devdocs all work in the
-- solution buffer, so interview practice happens in the real environment.
--
-- :Leet          open the problem menu (first use: :Leet signin — paste
--                your leetcode.com session cookie once)
-- :Leet list     browse/pick problems (work the NeetCode 150 from here)
-- :Leet test     run the problem's example test cases
-- :Leet submit   submit the current solution
-- :Leet random   random problem (filters: difficulty/topic)
return {
  "kawre/leetcode.nvim",
  build = ":TSUpdate html", -- problem descriptions render via the html parser
  cmd = "Leet",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  opts = {
    lang = "cpp",
    -- Prepended invisibly to every solution before compile/submit. Standard
    -- competitive shortcut; delete this block if you'd rather practice
    -- writing the exact includes you'd need in an interview editor.
    injector = {
      ["cpp"] = {
        before = { "#include <bits/stdc++.h>", "using namespace std;" },
      },
    },
  },
}

-- Completion, typed for real: each case starts the config in a tmux pane,
-- types a prefix one key at a time (nvim-cmp only auto-triggers on single
-- keystrokes, which a headless nvim can't produce), accepts, saves, and
-- checks the file. Pending without tmux.
local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/helpers.lua")

if vim.fn.executable("tmux") == 0 then
  describe("completion", function() pending("tmux not installed") end)
  return
end

local session = "nvim-completion-spec-" .. vim.uv.os_getpid()

-- A private tmux server with no config: the user's tmux.conf (continuum
-- auto-restoring a saved session when a server starts, for one) must not
-- reach into the session the keys are typed into.
local function tmux(...)
  return vim.system({ "tmux", "-L", "nvim-completion-spec", "-f", "/dev/null", ... }, { text = true }):wait()
end

local function sleep(ms)
  vim.wait(ms, function() return false end)
end

local function count(path, pattern)
  local n = 0
  for _, line in ipairs(vim.fn.readfile(path)) do
    if line:find(pattern) then n = n + 1 end -- (gmatch ignores ^ anchors)
  end
  return n
end

-- keys: list of { lit = "text" } (typed literally) or tmux key names.
local function run(file, lines, prefix, keys, expect)
  local dir = H.tmpdir()
  vim.fn.mkdir(dir .. "/.git", "p")
  H.write(dir, "compile_flags.txt", { "-std=c++20" })
  local path = H.write(dir, file, lines)
  local before = count(path, expect)

  tmux("kill-session", "-t", session)
  tmux("new-session", "-d", "-s", session, "-x", "110", "-y", "22", "-c", dir,
    -- The pane gets the tmux server's environment, not ours: say which
    -- config to run (the one these tests belong to) explicitly.
    "env", "XDG_STATE_HOME=" .. (vim.env.XDG_STATE_HOME or vim.fn.stdpath("state")),
    "XDG_CONFIG_HOME=" .. vim.fs.dirname(H.root), "NVIM_APPNAME=" .. vim.fs.basename(H.root),
    "nvim", "-u", H.root .. "/init.lua", file)
  local ok, err = pcall(function()
    sleep(5000) -- language servers start
    tmux("send-keys", "-t", session, "GO")
    sleep(300)
    for ch in prefix:gmatch(".") do
      tmux("send-keys", "-t", session, "-l", ch)
      sleep(150)
    end
    sleep(1200)
    for _, k in ipairs(keys) do
      if type(k) == "table" then
        tmux("send-keys", "-t", session, "-l", k.lit)
      else
        tmux("send-keys", "-t", session, k)
      end
      sleep(500)
    end
    tmux("send-keys", "-t", session, "Escape")
    sleep(200)
    tmux("send-keys", "-t", session, ":wq", "Enter")
    sleep(1000)
  end)
  tmux("kill-session", "-t", session)
  assert(ok, err)

  local after = count(path, expect)
  assert(after > before, ("no %q inserted; file is now:\n%s"):format(expect, table.concat(vim.fn.readfile(path), "\n")))
end

describe("completion (typed in a real terminal)", function()
  local fn_cpp = { "int add_numbers(int a, int b) { return a + b; }", "int main() {", "", "}" }

  it("C++: <CR> accepts the highlighted LSP item", function()
    run("main.cpp", fn_cpp, "add_n", { "Enter" }, "add_numbers%(")
  end)

  it("C++: <Tab> jumps between a function's argument placeholders", function()
    run("main.cpp", fn_cpp, "add_n", { "Enter", { lit = "1" }, "Tab", { lit = "2" } }, "add_numbers%(1, 2%)")
  end)

  it("bash: functions from the file", function()
    run("t.sh", { "#!/bin/bash", "my_function() { :; }", "" }, "my_f", { "Enter" }, "my_function")
  end)

  it("bash: commands", function()
    run("t.sh", { "#!/bin/bash", "" }, "ech", { "Enter" }, "^echo")
  end)

  it("bash: file paths", function()
    run("t.sh", { "#!/bin/bash", "" }, "cat ./compile_f", { "Enter" }, "compile_flags%.txt")
  end)

  it("Lua: the Neovim API (lazydev)", function()
    run("t.lua", { "local x = 1", "" }, "vim.api.nvim_buf_get_na", { "Enter" }, "nvim_buf_get_name")
  end)

  it("Python: module attributes", function()
    run("t.py", { "import os", "" }, "os.getc", { "Enter" }, "os%.getcwd")
  end)

  it("markdown: words from the buffer", function()
    run("t.md", { "# N", "", "Supercalifragilistic here.", "" }, "Supe", { "Enter" }, "Supercalifragilistic")
  end)

  it("<C-e> closes the menu so <CR> is a plain newline", function()
    run("t.txt", { "Supercalifragilistic here.", "" }, "Supe", { "C-e", "Enter", { lit = "x" } }, "^x$")
  end)

  it(": command line runs what you typed, not a menu item", function()
    run("t.txt", { "" }, "", { "Escape", ":let g:done = 'yes'", "Enter",
      ":call setline(1, g:done)", "Enter" }, "^yes$")
  end)
end)

-- :MarkdownGraph — draw the links between markdown notes as a mermaid
-- flowchart, rendered inline by snacks.image (see plugins/snacks.lua).
--
--   :MarkdownGraph      the current note, what it links to and what links to it
--   :MarkdownGraph 2    the same, two hops out
--   :MarkdownGraph!     every linked note under the vault root
--
-- The vault root is the nearest ancestor holding .obsidian (else .git, else
-- the note's own directory). Understands [[wiki]], [[wiki|alias]],
-- [[wiki#heading]] and [text](relative/path.md) links.
local M = {}

local MAX_FILES = 5000

-- Link targets in `text` as written: wiki names and relative .md paths.
function M.parse_links(text)
  local wiki, paths = {}, {}
  for inner in text:gmatch("%[%[(.-)%]%]") do
    local name = vim.trim(inner:gsub("|.*", ""):gsub("#.*", ""))
    if name ~= "" then
      wiki[#wiki + 1] = name
    end
  end
  for target in text:gmatch("%]%(([^)%s]+)") do
    target = target:gsub("#.*", ""):gsub("^<", ""):gsub(">$", "")
    if not target:match("^%a[%w+.-]*:") and target:match("%.md$") then
      paths[#paths + 1] = target:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    end
  end
  return wiki, paths
end

-- Strip fenced code so example links inside ``` blocks don't count.
local function strip_fences(text)
  local out, fenced = {}, false
  for line in (text .. "\n"):gmatch("(.-)\n") do
    if line:match("^%s*```") or line:match("^%s*~~~") then
      fenced = not fenced
    elseif not fenced then
      out[#out + 1] = line
    end
  end
  return table.concat(out, "\n")
end

-- { [abs path] = { [abs path] = true } } for every note under `root`.
function M.scan(root)
  local files = vim.fs.find(function(name) return name:match("%.md$") end,
    { path = root, type = "file", limit = MAX_FILES })
  local by_name = {}
  for _, f in ipairs(files) do
    local key = vim.fs.basename(f):gsub("%.md$", ""):lower()
    by_name[key] = by_name[key] or f
  end
  local edges = {}
  for _, f in ipairs(files) do
    local fd = io.open(f, "r")
    local text = fd and fd:read("*a") or ""
    if fd then fd:close() end
    local wiki, paths = M.parse_links(strip_fences(text))
    local out = {}
    for _, name in ipairs(wiki) do
      local key = vim.fs.basename(name):gsub("%.md$", ""):lower()
      local hit = by_name[key]
      if hit and hit ~= f then out[hit] = true end
    end
    for _, p in ipairs(paths) do
      local abs = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(f), p))
      abs = vim.uv.fs_realpath(abs) or abs
      if abs ~= f and vim.uv.fs_stat(abs) then out[abs] = true end
    end
    edges[vim.uv.fs_realpath(f) or f] = out
  end
  return edges
end

-- Notes within `depth` hops of `center`, following links both ways.
function M.neighbourhood(edges, center, depth)
  local back = {}
  for from, tos in pairs(edges) do
    for to in pairs(tos) do
      back[to] = back[to] or {}
      back[to][from] = true
    end
  end
  local keep, frontier = { [center] = true }, { center }
  for _ = 1, depth do
    local next_frontier = {}
    for _, n in ipairs(frontier) do
      for _, set in ipairs({ edges[n] or {}, back[n] or {} }) do
        for m in pairs(set) do
          if not keep[m] then
            keep[m] = true
            next_frontier[#next_frontier + 1] = m
          end
        end
      end
    end
    frontier = next_frontier
  end
  return keep
end

-- Mermaid source plus the ordered node list (for the clickable index).
function M.to_mermaid(edges, keep, center)
  local nodes = {}
  for n in pairs(keep) do nodes[#nodes + 1] = n end
  table.sort(nodes, function(a, b) return vim.fs.basename(a):lower() < vim.fs.basename(b):lower() end)
  local id = {}
  local lines = { "flowchart LR" }
  for i, n in ipairs(nodes) do
    id[n] = "n" .. i
    local label = vim.fs.basename(n):gsub("%.md$", ""):gsub('"', "#quot;")
    lines[#lines + 1] = ('  n%d["%s"]'):format(i, label)
  end
  for _, from in ipairs(nodes) do
    local tos = {}
    for to in pairs(edges[from] or {}) do
      if keep[to] then tos[#tos + 1] = to end
    end
    table.sort(tos, function(a, b) return id[a] < id[b] end)
    for _, to in ipairs(tos) do
      lines[#lines + 1] = ("  %s --> %s"):format(id[from], id[to])
    end
  end
  if center and id[center] then
    lines[#lines + 1] = "  classDef current stroke-width:3px,font-weight:bold"
    lines[#lines + 1] = ("  class %s current"):format(id[center])
  end
  return lines, nodes
end

function M.root_for(file)
  return vim.fs.root(file, ".obsidian") or vim.fs.root(file, ".git") or vim.fs.dirname(file)
end

function M.open(opts)
  opts = opts or {}
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("MarkdownGraph: buffer has no file", vim.log.levels.WARN)
    return
  end
  file = vim.uv.fs_realpath(file) or file
  local root = M.root_for(file)
  local edges = M.scan(root)

  local keep
  if opts.all then
    -- Whole vault: only notes with at least one link, in or out.
    keep = {}
    for from, tos in pairs(edges) do
      for to in pairs(tos) do
        keep[from], keep[to] = true, true
      end
    end
  else
    keep = M.neighbourhood(edges, file, opts.depth or 1)
  end
  if vim.tbl_count(keep) <= 1 then
    vim.notify("MarkdownGraph: no links found", vim.log.levels.INFO)
    return
  end

  local mermaid, nodes = M.to_mermaid(edges, keep, file)
  local title = opts.all and vim.fs.basename(root)
    or vim.fs.basename(file):gsub("%.md$", "") .. (opts.depth and opts.depth > 1 and (" (" .. opts.depth .. " hops)") or "")
  local lines = { "# Graph: " .. title, "", "```mermaid" }
  vim.list_extend(lines, mermaid)
  vim.list_extend(lines, { "```", "", "## Notes", "" })
  local index_start = #lines + 1
  for _, n in ipairs(nodes) do
    local rel = vim.fs.relpath(root, n) or n
    lines[#lines + 1] = ("- %s%s"):format(rel, n == file and "  *(current)*" or "")
  end

  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"
  pcall(vim.api.nvim_buf_set_name, buf, "markdown-graph://" .. title)

  local function open_under_cursor()
    local i = vim.api.nvim_win_get_cursor(0)[1] - index_start + 1
    local target = nodes[i]
    if not target then return end
    vim.cmd("tabclose")
    vim.cmd.edit(vim.fn.fnameescape(target))
  end
  vim.keymap.set("n", "<CR>", open_under_cursor, { buffer = buf, desc = "Open note" })
  vim.keymap.set("n", "q", "<cmd>tabclose<cr>", { buffer = buf, desc = "Close graph" })
end

function M.command(o)
  M.open({ all = o.bang, depth = tonumber(o.args) })
end

return M

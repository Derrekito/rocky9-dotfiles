-- Read and write a markdown buffer's YAML frontmatter.
--
-- Reading goes through pandoc (`$meta-json$`), so it's real YAML parsing.
-- Values come back as pandoc renders them to plain text: strings (numbers
-- included), booleans, lists and maps.
--
-- Writing only ever replaces the top-level `export:` block, so the rest of
-- the frontmatter keeps its formatting and comments.
local M = {}

-- 1-based {first, last} line numbers of the frontmatter fences, or nil.
function M.range(lines)
  if not (lines[1] and lines[1]:match("^%-%-%-%s*$")) then
    return nil
  end
  for i = 2, #lines do
    if lines[i]:match("^%-%-%-%s*$") or lines[i]:match("^%.%.%.%s*$") then
      return { 1, i }
    end
  end
  return nil
end

local template
local function meta_template()
  if not template then
    template = vim.fs.joinpath(vim.fn.stdpath("cache"), "markdown-export", "meta-json.tpl")
    vim.fn.mkdir(vim.fs.dirname(template), "p")
    vim.fn.writefile({ "$meta-json$" }, template)
  end
  return template
end

-- Parsed frontmatter of `lines` as a Lua table ({} when there is none).
function M.read(lines)
  local r = M.range(lines)
  if not r then
    return {}
  end
  local yaml = table.concat(vim.list_slice(lines, r[1], r[2]), "\n") .. "\n"
  local res = vim.system({ "pandoc", "-f", "markdown", "-t", "plain", "--template", meta_template() },
    { stdin = yaml, text = true }):wait()
  if res.code ~= 0 then
    error("frontmatter: " .. vim.trim(res.stderr or ""), 0)
  end
  local ok, meta = pcall(vim.json.decode, res.stdout ~= "" and res.stdout or "{}", { luanil = { object = true } })
  return ok and meta or {}
end

-- YAML serializer for the small values export: holds.
local function scalar(v)
  if type(v) == "boolean" or type(v) == "number" then
    return tostring(v)
  end
  v = tostring(v)
  if v == "" or v:match("^[%s%-?:,%[%]{}#&*!|>'\"%%@`]") or v:match(":%s") or v:match("%s#")
    or v:match("^%s") or v:match("%s$") or v == "true" or v == "false" or v == "null" or v == "~" then
    return vim.json.encode(v)
  end
  return v
end

local function is_list(t)
  return type(t) == "table" and (#t > 0 or next(t) == nil) and vim.islist(t)
end

local function emit(out, key, v, indent)
  local pad = string.rep("  ", indent)
  if type(v) == "table" and not is_list(v) then
    out[#out + 1] = pad .. key .. ":"
    local keys = vim.tbl_keys(v)
    table.sort(keys, function(a, b)
      -- `format` first, then plain settings, then the per-format maps.
      local function rank(k)
        return k == "format" and 0 or (type(v[k]) == "table" and not is_list(v[k])) and 2 or 1
      end
      if rank(a) ~= rank(b) then return rank(a) < rank(b) end
      return a < b
    end)
    for _, k in ipairs(keys) do
      emit(out, k, v[k], indent + 1)
    end
  elseif type(v) == "table" then
    out[#out + 1] = pad .. key .. ": [" .. table.concat(vim.tbl_map(scalar, v), ", ") .. "]"
  else
    out[#out + 1] = pad .. key .. ": " .. scalar(v)
  end
end

-- `lines` with the frontmatter's export: block replaced by `export`
-- (frontmatter created if missing).
function M.with_export(lines, export)
  local block = {}
  emit(block, "export", export, 0)
  local r = M.range(lines)
  local out = vim.list_slice(lines, 1, #lines)
  if not r then
    local fm = { "---" }
    vim.list_extend(fm, block)
    vim.list_extend(fm, { "---", "" })
    vim.list_extend(fm, out)
    return fm
  end
  local first, last = nil, r[2] - 1
  for i = r[1] + 1, r[2] - 1 do
    if out[i]:match("^export:") then
      first = i
      last = i
      for j = i + 1, r[2] - 1 do
        if out[j]:match("^%s") or out[j] == "" then last = j else break end
      end
      -- Keep blank lines that separated export: from the next key.
      while last > first and out[last] == "" do last = last - 1 end
      break
    end
  end
  if first then
    for _ = first, last do table.remove(out, first) end
    for k, l in ipairs(block) do table.insert(out, first + k - 1, l) end
  else
    for k, l in ipairs(block) do table.insert(out, r[2] + k - 1, l) end
  end
  return out
end

return M

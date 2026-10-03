-- Pandoc Lua filter used by :MarkdownExport (lua/config/export/).
--
--   ```mermaid blocks   -> figure via mmdc: PDF for LaTeX/Beamer output, PNG
--                          for everything else (DOCX). Cached by content hash.
--   > [!NOTE] callouts  -> Beamer: block / exampleblock / alertblock.
--                          Other formats: the quote keeps a bold "Note:" label
--                          in place of the raw [!NOTE] marker.
--
-- Metadata it reads (passed with -M):
--   mermaid-config   mmdc -c JSON theme (optional)
--   mermaid-cache    directory for rendered diagrams (default: .)
--   mermaid-bin      mmdc executable; without it mermaid blocks stay code
--   mermaid-puppeteer  mmdc -p JSON: which Chrome to drive, and its args (optional)

local config, cache, mmdc, puppeteer = nil, ".", nil, nil

-- pandoc.utils.sha1 on current pandoc; older releases (2.x) also have pandoc.sha1.
local sha1 = (pandoc.utils and pandoc.utils.sha1) or pandoc.sha1

local function meta_str(v)
  return v and pandoc.utils.stringify(v) or nil
end

local function exists(path)
  local f = io.open(path, "r")
  if f then f:close() end
  return f ~= nil
end

local function is_latex()
  return FORMAT == "latex" or FORMAT == "beamer"
end

local fit
local function pdf_fit()
  if fit == nil then
    local ok, help = pcall(pandoc.pipe, mmdc, { "--help" }, "")
    fit = ok and help:find("pdfFit", 1, true) ~= nil
  end
  return fit
end

local function mermaid(block)
  -- pandoc 2.x aborts outright (no pcall can catch it) when asked to run a
  -- program that doesn't exist, so only ever run an mmdc we can see.
  if not mmdc or (mmdc:find("/") and not exists(mmdc)) then
    return nil -- leave the source as a code block
  end
  local ext = is_latex() and "pdf" or "png"
  local out = cache .. "/" .. sha1(block.text .. (config or "")) .. "." .. ext
  if not exists(out) then
    pcall(pandoc.system.make_directory, cache, true)
    local src = out:gsub("%.%a+$", ".mmd")
    local f = io.open(src, "w")
    if not f then
      io.stderr:write("mermaid: cannot write " .. src .. "\n")
      return nil -- leave the source as a code block
    end
    f:write(block.text)
    f:close()
    -- PDF: transparent, trimmed to the diagram. PNG: 3x for crisp Word
    -- documents, white so it reads on any page color.
    local args = ext == "pdf" and { "-i", src, "-o", out, "-b", "transparent" }
      or { "-i", src, "-o", out, "-b", "white", "-s", "3" }
    -- mermaid-cli < 12 needs --pdfFit to size the page to the diagram; 12
    -- does that by default and rejects the flag.
    if ext == "pdf" and pdf_fit() then
      table.insert(args, "--pdfFit")
    end
    if config then
      table.insert(args, "-c")
      table.insert(args, config)
    end
    if puppeteer then
      table.insert(args, "-p")
      table.insert(args, puppeteer)
    end
    local ok, err = pcall(pandoc.pipe, mmdc, args, "")
    if not ok or not exists(out) then
      io.stderr:write("mermaid: " .. tostring(err) .. "\n")
      return nil
    end
  end
  local attr = is_latex() and { height = "0.8\\textheight" } or { width = "100%" }
  return pandoc.Para({ pandoc.Image({}, out, "", attr) })
end

local callouts = {
  NOTE = { "block", "Note" },
  TIP = { "exampleblock", "Tip" },
  IMPORTANT = { "block", "Important" },
  WARNING = { "alertblock", "Warning" },
  CAUTION = { "alertblock", "Caution" },
}

local function callout(quote)
  local first = quote.content[1]
  if not first or first.t ~= "Para" or not first.content[1] then
    return nil
  end
  local kind = pandoc.utils.stringify(first.content[1]):match("^%[!(%u+)%]$")
  local spec = kind and callouts[kind]
  if not spec then
    return nil
  end
  -- Drop the [!KIND] marker and the break after it.
  local rest = pandoc.List({})
  for i = 2, #first.content do rest:insert(first.content[i]) end
  while rest[1] and (rest[1].t == "SoftBreak" or rest[1].t == "LineBreak" or rest[1].t == "Space") do
    rest:remove(1)
  end
  local env, title = spec[1], spec[2]

  if FORMAT ~= "beamer" then
    local label = pandoc.List({ pandoc.Strong({ pandoc.Str(title .. ":") }), pandoc.Space() })
    label:extend(rest)
    quote.content[1] = pandoc.Para(label)
    return quote
  end

  local out = pandoc.List({ pandoc.RawBlock("latex", ("\\begin{%s}{%s}"):format(env, title)) })
  if #rest > 0 then out:insert(pandoc.Para(rest)) end
  for i = 2, #quote.content do out:insert(quote.content[i]) end
  out:insert(pandoc.RawBlock("latex", ("\\end{%s}"):format(env)))
  return out
end

return {
  {
    Meta = function(m)
      config = meta_str(m["mermaid-config"])
      cache = meta_str(m["mermaid-cache"]) or cache
      mmdc = meta_str(m["mermaid-bin"])
      puppeteer = meta_str(m["mermaid-puppeteer"])
    end,
  },
  {
    CodeBlock = function(b)
      if b.classes:includes("mermaid") then
        return mermaid(b)
      end
    end,
    BlockQuote = callout,
  },
}

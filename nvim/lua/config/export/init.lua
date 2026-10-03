-- Markdown export: PDF document, DOCX, or PDF slides via pandoc.
--
-- Settings come from, lowest to highest precedence:
--   1. built-in defaults for the format (below)
--   2. frontmatter `export:` keys shared by every format
--   3. frontmatter `export.<format>:` keys
--   4. per-run choices made in the :MarkdownExport window
--
--   ---
--   title: Sprint 42          # title/author/date/... are ordinary pandoc
--   author: Derrek            # metadata and work in every format
--   export:
--     format: slides          # what this note usually exports to: preselected
--                             # in the window (pdf, docx or slides)
--     filters: [extra.lua]    # added to the format's default filters
--     pdf:
--       toc: true
--       template: ~/some/template.latex
--     docx:
--       template: ~/templates/company.docx   # default: ./template.docx
--                                            # beside the note, if present
--     slides:
--       theme: RosePineMoon
--       aspectratio: 169
--   ---
--
-- Recognized keys (shared or per format):
--   template, defaults                  files (~ and note-relative paths ok).
--                                       For docx, template is the .docx to copy
--                                       styles from (alias: reference-doc);
--                                       template: false skips ./template.docx
--   filters                             list; .lua -> --lua-filter, else --filter.
--                                       Bare names are also looked up in the
--                                       manual-pipeline and nvim filter dirs.
--   default-filters: false              drop the format's built-in filters
--   toc, number-sections                booleans
--   variables, metadata                 maps -> -V k=v / -M k=v
--   theme, aspectratio, colortheme,
--   fonttheme, innertheme, outertheme   slides: shorthands for -V
--   output                              file or directory for the result
--   open                                open the result when done (default true)
-- Any other key is passed straight to pandoc: `foo: x` -> --foo=x,
-- `foo: true` -> --foo.
--
-- PDF documents default to ~/Projects/manual-pipeline (its template, filters,
-- fonts and logos, built with LuaLaTeX); without that checkout they fall back
-- to pandoc's own LaTeX template.
local fm = require("config.export.frontmatter")

local M = {}

M.order = { "pdf", "docx", "slides" }
M.formats = {
  pdf = { label = "PDF document", suffix = ".pdf" },
  docx = { label = "Word (DOCX)", suffix = ".docx" },
  slides = { label = "PDF slides", suffix = "-slides.pdf" },
}

M.pipeline_dir = vim.fn.expand("~/Projects/manual-pipeline")

-- pandoc renamed --highlight-style to --syntax-highlighting in 3.8; Rocky 9
-- ships 2.14. Returns the flag this pandoc understands.
local hl_flag
function M.highlight_flag()
  if not hl_flag then
    local v = vim.fn.system({ "pandoc", "--version" }):match("pandoc%S* (%d+%.%d+)")
    local major, minor = (v or "0.0"):match("(%d+)%.(%d+)")
    major, minor = tonumber(major), tonumber(minor)
    hl_flag = (major > 3 or (major == 3 and minor >= 8)) and "--syntax-highlighting" or "--highlight-style"
  end
  return hl_flag
end

-- Slide theme. The full RosePineMoon theme needs minted (and fvextra); where
-- TeX Live lacks them (Rocky 9) use its color/font/inner/outer parts, which
-- only need TikZ. Without the theme at all, Beamer's default.
local beamer_vars
function M.beamer_theme()
  if not beamer_vars then
    local function has(file)
      return vim.fn.executable("kpsewhich") == 1 and vim.trim(vim.fn.system({ "kpsewhich", file })) ~= ""
    end
    if has("beamerthemeRosePineMoon.sty") and has("minted.sty") then
      beamer_vars = { theme = "RosePineMoon" }
    elseif has("beamercolorthemeRosePineMoon.sty") then
      beamer_vars = { colortheme = "RosePineMoon", fonttheme = "RosePineMoon",
        innertheme = "RosePineMoon", outertheme = "RosePineMoon" }
    else
      beamer_vars = {}
    end
  end
  return beamer_vars
end

local function nvim_filter()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "pandoc", "export.lua")
end

local function have_pipeline()
  return vim.fn.filereadable(M.pipeline_dir .. "/latex/template.latex") == 1
end

local function mp(rel)
  return M.pipeline_dir .. "/" .. rel
end

-- Built-in defaults per format. `profile` is shown in the window.
function M.defaults(format)
  if format == "pdf" and have_pipeline() then
    return {
      profile = "manual-pipeline",
      from = "markdown+raw_tex",
      template = mp("latex/template.latex"),
      filters = {
        mp("scripts/inject_logos.py"),
        mp("latex/filters/include-files.lua"),
        mp("latex/filters/readme-only.lua"),
        mp("latex/filters/notebook-toggle.lua"),
        mp("latex/filters/nobreak-codeblock.lua"),
        mp("latex/filters/md-links-to-refs.lua"),
        mp("latex/filters/pandoc-mermaid.py"),
        mp("latex/filters/pandoc-minted.py"),
        nvim_filter(), -- callouts; mermaid is already handled above
      },
      ["syntax-highlighting"] = "pygments",
      toc = false,
      ["number-sections"] = false,
      latex = true, -- pandoc -> .tex, then latexmk (lualatex, shell-escape)
      preprocess = mp("scripts/preprocess-acronyms.sh"),
    }
  elseif format == "pdf" then
    return {
      profile = "pandoc LaTeX",
      from = "markdown",
      filters = { nvim_filter() },
      toc = false,
      ["number-sections"] = false,
      latex = true,
    }
  elseif format == "docx" then
    local filters = {}
    if have_pipeline() then
      filters = {
        mp("latex/filters/include-files.lua"),
        mp("latex/filters/notebook-toggle.lua"),
        mp("latex/filters/md-links-to-refs.lua"),
      }
    end
    -- manual-pipeline's mermaid filter only emits LaTeX; ours makes PNGs.
    table.insert(filters, nvim_filter())
    return {
      profile = have_pipeline() and "manual-pipeline filters" or "pandoc",
      from = have_pipeline() and "markdown+raw_tex" or "markdown",
      filters = filters,
      toc = false,
      ["number-sections"] = false,
    }
  elseif format == "slides" then
    local theme = M.beamer_theme()
    return vim.tbl_extend("force", {
      profile = theme.theme and "Beamer RosePineMoon"
        or theme.colortheme and "Beamer RosePineMoon (no minted)" or "Beamer",
      from = "markdown",
      filters = { nvim_filter() },
      ["slide-level"] = "2",
      aspectratio = "169",
      toc = false,
      ["number-sections"] = false,
      rose_pine = true,
    }, theme)
  end
  error("unknown format " .. tostring(format))
end

-- Keys this module interprets itself; anything else goes to pandoc verbatim.
local KNOWN = {
  format = true, filters = true, ["default-filters"] = true, template = true, ["reference-doc"] = true,
  defaults = true, toc = true, ["number-sections"] = true, variables = true, metadata = true,
  output = true, open = true, theme = true, aspectratio = true, colortheme = true, fonttheme = true,
  innertheme = true, outertheme = true, ["syntax-highlighting"] = true,
  -- internal
  profile = true, from = true, latex = true, preprocess = true, rose_pine = true,
}

local function truthy(v)
  return v == true or v == "true" or v == "yes"
end

local function expand(path, dir)
  path = vim.fn.expand(path)
  if not path:match("^/") then
    path = vim.fs.joinpath(dir, path)
  end
  return vim.fs.normalize(path)
end

-- A filter named in frontmatter: note-relative/absolute path first, then a
-- bare name in the manual-pipeline or nvim filter directories.
function M.find_filter(name, dir)
  local p = expand(name, dir)
  if vim.uv.fs_stat(p) then
    return p
  end
  if not name:find("/") then
    for _, d in ipairs({ mp("latex/filters"), mp("scripts"), vim.fs.dirname(nvim_filter()) }) do
      local c = vim.fs.joinpath(d, name)
      if vim.uv.fs_stat(c) then
        return c
      end
    end
  end
  return p -- let pandoc report it
end

local function is_map(v)
  return type(v) == "table" and not vim.islist(v)
end

-- Fully merged options for `format`. `meta` is the parsed frontmatter.
function M.resolve(src, meta, format, overrides)
  local dir = vim.fs.dirname(src)
  local export = is_map(meta.export) and meta.export or {}
  local opts = M.defaults(format)
  local extra_filters = {}

  local function layer(t)
    for k, v in pairs(t or {}) do
      if k == "filters" then
        for _, f in ipairs(type(v) == "table" and v or { v }) do
          table.insert(extra_filters, M.find_filter(f, dir))
        end
      elseif (k == "variables" or k == "metadata") and is_map(v) then
        opts[k] = vim.tbl_extend("force", opts[k] or {}, v)
      elseif not (M.formats[k] and is_map(v)) then
        opts[k] = v
      end
    end
  end
  layer(export)
  layer(is_map(export[format]) and export[format] or nil)
  layer(overrides)

  if opts["default-filters"] ~= nil and not truthy(opts["default-filters"]) then
    opts.filters = {}
  end
  vim.list_extend(opts.filters, extra_filters)

  -- DOCX has no pandoc template, only a reference document to copy styles
  -- from, so `template:` names that .docx (`reference-doc:` also works).
  -- Without either, a template.docx beside the note is used;
  -- `template: false` turns that lookup off.
  if format == "docx" then
    local t = opts["reference-doc"] or opts.template
    opts.template = nil
    if t == false or t == "false" then
      opts["reference-doc"] = nil
    elseif type(t) == "string" and t:match("%.docx$") then
      opts["reference-doc"] = t
    else
      local local_tpl = vim.fs.joinpath(dir, "template.docx")
      opts["reference-doc"] = vim.uv.fs_stat(local_tpl) and local_tpl or nil
    end
  end
  for _, k in ipairs({ "template", "reference-doc", "defaults" }) do
    if type(opts[k]) == "string" then
      opts[k] = expand(opts[k], dir)
    end
  end
  opts.toc = truthy(opts.toc)
  opts["number-sections"] = truthy(opts["number-sections"])
  opts.open = opts.open == nil or truthy(opts.open)

  local name = vim.fs.basename(src):gsub("%.md$", ""):gsub("%.markdown$", "")
  local file = name .. M.formats[format].suffix
  if type(opts.output) == "string" and opts.output ~= "" then
    local o = expand(opts.output, dir)
    opts.out = o:match("%.%w+$") and o or vim.fs.joinpath(o, file)
  else
    opts.out = vim.fs.joinpath(dir, file)
  end
  opts.format, opts.src, opts.dir = format, src, dir
  opts.build = vim.fs.joinpath(vim.fn.stdpath("cache"), "markdown-export", vim.fn.sha256(src):sub(1, 12))
  return opts
end

-- Ordered steps: { { cmd = argv, env = {...}, cwd = dir, desc = "..." }, ... }
function M.steps(o)
  local base = vim.fs.basename(o.src):gsub("%.md$", "")
  local input = o.src
  local steps = {}
  local env = {}
  if o.profile == "manual-pipeline" then
    env = {
      PIPELINE_DIR = M.pipeline_dir,
      TEXINPUTS = mp("assets/logos") .. ":" .. mp("assets/Fonts") .. ":",
      LUAFONTDIR = mp("assets/Fonts"),
      MERMAID_FILTER_CONFIG = mp("config/mermaid-config.json"),
      MERMAID_FILTER_MERMAID_CSS = mp("config/mermaid.css"),
      MERMAID_BIN = mp("node_modules/.bin/mmdc"),
      MERMAID_OUTPUT_DIR = o.build .. "/mermaid_images",
    }
  end

  if o.preprocess and vim.fn.executable(o.preprocess) == 1 then
    -- manual-pipeline protects \ac{} acronyms before pandoc sees them. Kept
    -- beside the note so relative includes still resolve; removed after.
    input = vim.fs.joinpath(o.dir, "." .. base .. "_preprocessed.md")
    table.insert(steps, { desc = "preprocess", cmd = { o.preprocess, o.src }, stdout = input, cleanup = input })
  end

  local mmdc = vim.fn.exepath("mmdc")
  local cmd = { "pandoc", input, "--from", o.from, "--to", o.format == "docx" and "docx" or o.format == "slides" and "beamer" or "latex" }
  local function add(...) vim.list_extend(cmd, { ... }) end
  add("--resource-path", o.dir)
  if o.template then add("--template", o.template) end
  if o["reference-doc"] then add("--reference-doc", o["reference-doc"]) end
  if o.defaults then add("--defaults", o.defaults) end
  for _, f in ipairs(o.filters) do
    add(f:match("%.lua$") and "--lua-filter" or "--filter", f)
  end
  if o.toc then add("--toc") end
  if o["number-sections"] then add("--number-sections") end
  for _, k in ipairs({ "theme", "aspectratio", "colortheme", "fonttheme", "innertheme", "outertheme" }) do
    if o[k] and o.format == "slides" then add("-V", k .. "=" .. o[k]) end
  end
  for k, v in pairs(o.variables or {}) do add("-V", k .. "=" .. tostring(v)) end
  for k, v in pairs(o.metadata or {}) do add("-M", k .. "=" .. tostring(v)) end
  add("-M", "mermaid-cache=" .. o.build .. "/mermaid")
  if mmdc ~= "" then add("-M", "mermaid-bin=" .. mmdc) end
  -- Which Chrome mmdc drives, where it isn't puppeteer's own download (Rocky's
  -- provision/export-tools.sh writes this for EPEL's headless Chromium).
  local puppeteer = vim.env.MERMAID_PUPPETEER_CONFIG or "/etc/mermaid/puppeteer.json"
  if vim.fn.filereadable(puppeteer) == 1 then add("-M", "mermaid-puppeteer=" .. puppeteer) end
  if o.rose_pine then
    add("-M", "mermaid-config=" .. require("config.markdown").mermaid_config())
    add(M.highlight_flag() .. "=" .. require("config.export.highlight").theme(o.build))
  elseif o["syntax-highlighting"] then
    add(M.highlight_flag() .. "=" .. o["syntax-highlighting"])
  end
  if o.profile == "manual-pipeline" then
    add("-M", "output_dir=" .. o.build .. "/mermaid_images")
  end
  local keys = vim.tbl_keys(o)
  table.sort(keys)
  for _, k in ipairs(keys) do
    local v = o[k]
    if not KNOWN[k] and not ({ out = 1, format = 1, src = 1, dir = 1, build = 1 })[k] then
      if v == true then
        add("--" .. k)
      elseif type(v) == "string" or type(v) == "number" then
        add("--" .. k .. "=" .. v)
      end
    end
  end

  -- manual-pipeline's mermaid filter writes into
  -- $MERMAID_OUTPUT_DIR/mermaid-images (create_pdf.sh pre-creates it) and
  -- also makes a mermaid-images/ dir in its cwd; run pandoc from the build
  -- dir so that one doesn't land beside the note. Includes and images are
  -- still resolved from the note (input path / --resource-path).
  local pandoc_cwd = o.dir
  if o.profile == "manual-pipeline" then
    pandoc_cwd = o.build
    table.insert(steps, { desc = "prepare", fn = function()
      vim.fn.mkdir(o.build .. "/mermaid_images/mermaid-images", "p")
    end })
  end

  if o.latex then
    local tex = vim.fs.joinpath(o.build, base .. ".tex")
    -- A whole document, not a fragment. (--template implies this; pandoc's
    -- own template, used without manual-pipeline, needs it spelled out.)
    add("--standalone", "-o", tex)
    table.insert(steps, { desc = "pandoc", cmd = cmd, env = env, cwd = pandoc_cwd })
    -- manual-pipeline fonts are loaded from ./assets/Fonts (linked into the
    -- build dir) and LuaTeX re-opens them at the end of the run, so LaTeX
    -- has to run from there; the note's dir goes on TEXINPUTS so images
    -- referenced relative to the note still resolve.
    local latex_env = vim.tbl_extend("force", env, {
      TEXINPUTS = o.dir .. "//:" .. (env.TEXINPUTS or ""),
    })
    table.insert(steps, {
      desc = "lualatex",
      cwd = o.profile == "manual-pipeline" and o.build or o.dir,
      env = latex_env,
      cmd = {
        "latexmk", "-lualatex", "-shell-escape", "-interaction=nonstopmode", "-halt-on-error",
        -- Older templates (manual-pipeline's) lack the counter pandoc >= 3
        -- tables need; define it if the template didn't.
        [[-usepretex=\makeatletter\@ifundefined{c@none}{\newcounter{none}}{}\makeatother]],
        "-output-directory=" .. o.build, tex,
      },
      result = vim.fs.joinpath(o.build, base .. ".pdf"),
    })
  else
    if o.format == "slides" then
      add("--pdf-engine", "lualatex", "--pdf-engine-opt=-shell-escape")
    end
    add("-o", o.out)
    table.insert(steps, { desc = "pandoc", cmd = cmd, env = env, cwd = o.dir,
      needs = o.format == "slides" and { "lualatex" } or nil })
  end
  return steps
end

-- Shell-ish one-liner per step, for the window's command preview.
function M.describe(steps)
  local lines = {}
  for _, s in ipairs(steps) do
    if not s.cmd then goto continue end
    local parts = {}
    for k, v in pairs(s.env or {}) do
      if k == "MERMAID_BIN" or k == "TEXINPUTS" then parts[#parts + 1] = k .. "=" .. vim.fn.shellescape(v) end
    end
    for _, a in ipairs(s.cmd) do parts[#parts + 1] = vim.fn.shellescape(a) end
    if s.stdout then parts[#parts + 1] = "> " .. vim.fn.shellescape(s.stdout) end
    lines[#lines + 1] = table.concat(parts, " ")
    ::continue::
  end
  return lines
end

-- Pull the useful lines out of a failed step's output.
local function errors(text)
  local out = {}
  for line in (text or ""):gmatch("[^\n]+") do
    if line:match("^!") or line:match("[Ee]rror") or line:match("^%[ERROR%]") then
      out[#out + 1] = line
    end
  end
  return #out > 0 and out or vim.list_slice(vim.split(text or "", "\n", { trimempty = true }), 1, 10)
end

M.last_log = nil

-- Run `o` asynchronously; notifies progress and opens the result.
-- Executables the steps need that aren't installed (pandoc, latexmk, ...).
function M.missing_tools(steps)
  local missing = {}
  for _, s in ipairs(steps) do
    -- The step's program, plus any it runs itself (pandoc's PDF engine).
    for _, exe in ipairs(s.cmd and vim.list_extend({ s.cmd[1] }, s.needs or {}) or {}) do
      local name = vim.fs.basename(exe)
      if vim.fn.executable(exe) == 0 and not vim.tbl_contains(missing, name) then
        missing[#missing + 1] = name
      end
    end
  end
  return missing
end

function M.run(o, done)
  local steps = M.steps(o)
  local missing = M.missing_tools(steps)
  if #missing > 0 then
    vim.notify("Export: not installed here: " .. table.concat(missing, ", "), vim.log.levels.ERROR)
    if done then done(false) end
    return
  end
  vim.fn.mkdir(o.build, "p")
  -- The filter can't create it on pandoc < 2.19 (no pandoc.system.make_directory).
  vim.fn.mkdir(o.build .. "/mermaid", "p")
  vim.fn.mkdir(vim.fs.dirname(o.out), "p")
  if o.profile == "manual-pipeline" then
    -- Its fonts.latex loads fonts from ./assets/Fonts/; create_pdf.sh links
    -- the pipeline's assets into the build dir for that, so do the same.
    local link = vim.fs.joinpath(o.build, "assets")
    if not vim.uv.fs_lstat(link) then
      vim.uv.fs_symlink(mp("assets"), link)
    end
  end
  local log_path = vim.fs.joinpath(o.build, "export-" .. o.format .. ".log")
  local log = { "# " .. os.date() .. "  " .. o.src .. " -> " .. o.out, "" }
  M.last_log = log_path
  local cleanups = {}

  local function finish(ok, msg)
    for _, f in ipairs(cleanups) do os.remove(f) end
    vim.fn.writefile(log, log_path)
    vim.schedule(function()
      if ok then
        vim.notify("Export: wrote " .. vim.fn.fnamemodify(o.out, ":~:."), vim.log.levels.INFO)
        if o.open then vim.ui.open(o.out) end
      else
        vim.notify("Export failed (" .. msg .. "), :MarkdownExportLog for details", vim.log.levels.ERROR)
      end
      if done then done(ok) end
    end)
  end

  local function step(i)
    local s = steps[i]
    if not s then
      return finish(true)
    end
    if s.cleanup then cleanups[#cleanups + 1] = s.cleanup end
    if s.fn then
      s.fn()
      return step(i + 1)
    end
    vim.list_extend(log, { "$ " .. M.describe({ s })[1], "" })
    -- schedule_wrap: the steps call vim.fn, which isn't allowed in the
    -- libuv callback context vim.system calls back in.
    vim.system(s.cmd, { cwd = s.cwd, env = s.env, text = true }, vim.schedule_wrap(function(r)
      vim.list_extend(log, vim.split((r.stdout or "") .. (r.stderr or ""), "\n"))
      if s.stdout and r.code == 0 then
        local f = io.open(s.stdout, "w")
        if f then f:write(r.stdout) f:close() end
      end
      if r.code ~= 0 then
        local errs = errors((r.stderr or "") .. "\n" .. (r.stdout or ""))
        if s.desc == "lualatex" then
          local tex_log = s.result:gsub("%.pdf$", ".log")
          local lf = io.open(tex_log, "r")
          if lf then errs = errors(lf:read("*a")) lf:close() end
        end
        vim.list_extend(log, { "", "FAILED: " .. s.desc })
        vim.schedule(function()
          vim.notify(table.concat(vim.list_slice(errs, 1, 8), "\n"), vim.log.levels.ERROR, { title = "Export: " .. s.desc })
        end)
        return finish(false, s.desc)
      end
      if s.result then
        local ok = vim.uv.fs_copyfile(s.result, o.out)
        if not ok then
          return finish(false, "copy result")
        end
      end
      step(i + 1)
    end))
  end

  vim.notify(("Export: %s -> %s …"):format(M.formats[o.format].label, vim.fs.basename(o.out)), vim.log.levels.INFO)
  step(1)
end

-- Entry points --------------------------------------------------------------

local function source_of(buf)
  local src = vim.api.nvim_buf_get_name(buf)
  if src == "" then
    vim.notify("Export: save the note first", vim.log.levels.WARN)
    return nil
  end
  if vim.bo[buf].modified then
    vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
  end
  return src
end

function M.meta(buf)
  local ok, meta = pcall(fm.read, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
  if not ok then
    vim.notify(tostring(meta), vim.log.levels.ERROR)
    return {}
  end
  return meta
end

-- :MarkdownExport [pdf|docx|slides] — no argument opens the window.
function M.command(o)
  local buf = vim.api.nvim_get_current_buf()
  local format = o.fargs[1]
  if not format then
    return require("config.export.ui").open(buf)
  end
  if not M.formats[format] then
    vim.notify("Export: unknown format " .. format .. " (pdf, docx, slides)", vim.log.levels.ERROR)
    return
  end
  local src = source_of(buf)
  if src then
    M.run(M.resolve(src, M.meta(buf), format))
  end
end

M.source_of = source_of

return M

-- weft-output.lua: the rendered-output check (dev/design-7.md section 2.D, N50 to N59).
--
-- Runs last, on the document's final tree: under Quarto after its own filters (a `filters:` entry of
-- `_quarto.yml` with `at: post-render`, which use_quarto() writes), under rmarkdown as the last
-- `--lua-filter`, in plain Pandoc by hand as the last filter. It reports three kinds of finding and
-- changes nothing in the document:
--   unresolved reference   Quarto printed `?@id`, `?meta:key` or `?var:key` (Quarto only)
--   missing value in output  `NA`, `NaN`, `Inf` ... in prose
--   leftover markup          `:::`, a shown attribute block, `\@ref(` (Quarto only)
-- Settings: `output_refs`, `output_missing`, `output_markup`, each fail, warn or off.
--
-- Reporting: with the collection file open each finding is a JSON line in it and the filter does not
-- exit; otherwise the report goes to stderr and the filter exits 1 on a `fail` finding (not in draft
-- mode). WEFT_OUTPUT_LOG, when set, also receives each finding as a JSON line.
--
-- Not self-contained: the modules of weftlib/ load from the folder beside this file.

local HERE = pandoc.path.directory(PANDOC_SCRIPT_FILE or "")
if HERE == "" then HERE = "." end

local function truthy_env(name)
  local v = os.getenv(name)
  if v == nil then return false end
  v = v:lower()
  return v == "1" or v == "true"
end

local function lib(name) return dofile(HERE .. "/weftlib/" .. name .. ".lua") end
local config = lib("config")
local report = lib("report")

local IN_QUARTO = quarto ~= nil

-- ---- the source and the project -----------------------------------------------------------------

local function map_knit(path)
  local base = path:match("^(.*)%.[Kk][Nn][Ii][Tt]%.[Mm][Dd]$")
  if not base then return path end
  for _, ext in ipairs({ ".Rmd", ".Rmarkdown", ".rmd", ".rmarkdown" }) do
    local f = io.open(base .. ext, "rb")
    if f then f:close(); return base .. ext end
  end
  return path
end

local function source_path()
  if quarto and quarto.doc and quarto.doc.input_file then return quarto.doc.input_file end
  local inputs = PANDOC_STATE and PANDOC_STATE.input_files
  if inputs then
    for _, f in ipairs(inputs) do
      if f ~= nil and f ~= "" and f ~= "-" then return map_knit(f) end
    end
  end
  return nil
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

local MAIN_DIR = nil

local function dir_up_find(rel)
  local starts = {}
  local ok, cwd = pcall(pandoc.system.get_working_directory)
  if ok and cwd then starts[#starts + 1] = cwd end
  if MAIN_DIR then starts[#starts + 1] = MAIN_DIR end
  for _, d in ipairs(starts) do
    local cur = d
    for _ = 1, 9 do
      local p = cur .. "/" .. rel
      local f = io.open(p, "r")
      if f then return f, p end
      local parent = (cur:gsub("[/\\]+[^/\\]*$", ""))
      if parent == cur or parent == "" then break end
      cur = parent
    end
  end
  return nil
end

-- ---- the findings -------------------------------------------------------------------------------

local KIND_REF, KIND_MISSING, KIND_MARKUP = "unresolved reference", "missing value in output", "leftover markup"
local SETTING = { [KIND_REF] = "output_refs", [KIND_MISSING] = "output_missing", [KIND_MARKUP] = "output_markup" }

local S = { found = {}, seen = {}, section = "", cfg = nil, file = "" }

local function collapse(s)
  s = s:gsub("%z", ""):gsub("[ \t\r\n]+", " ")
  return (s:gsub("^ ", ""):gsub(" $", ""))
end

-- the excerpt: the white-space-collapsed block, cut to 80 characters around the token with "..." at each
-- cut end
local function cut(s, token)
  local len = utf8.len(s)
  if not len or len <= 80 then return s end
  local at = token and s:find(token, 1, true) or 1
  local posc = (utf8.len(s, 1, at - 1) or 0) + 1
  local tl = token and utf8.len(token) or 1
  local startc = posc - ((80 - (tl or 1)) // 2)
  if startc > len - 79 then startc = len - 79 end
  if startc < 1 then startc = 1 end
  local endc = startc + 79
  local b1 = utf8.offset(s, startc)
  local b2 = utf8.offset(s, endc + 1) - 1
  local out = s:sub(b1, b2)
  if startc > 1 then out = "..." .. out end
  if endc < len then out = out .. "..." end
  return out
end

local function add(kind, text, holder, hint)
  local level = S.cfg[SETTING[kind]]
  if level == "off" then return end
  local key = kind .. "\0" .. text .. "\0" .. S.section
  if S.seen[key] then return end
  S.seen[key] = true
  local ex = collapse(pandoc.utils.stringify(pandoc.Plain(holder)))
  S.found[#S.found + 1] = { kind = kind, level = level, section = S.section, text = text,
                            excerpt = cut(ex, hint or text) }
end

-- ---- the tokens -----------------------------------------------------------------------------------

local MISSING = { NA = true, NaN = true, nan = true, Inf = true, ["-Inf"] = true, ["\u{2212}Inf"] = true,
                  inf = true, ["-inf"] = true }
local LEADING = { "(", "[", "\"", "'", "\u{201c}", "\u{2018}" }
local TRAILING = { ".", ",", ";", ":", "!", "?", ")", "]", "%", "\"", "'", "\u{201d}", "\u{2019}" }

local function strip_ends(s)
  local again = true
  while again do
    again = false
    for _, p in ipairs(LEADING) do
      if s:sub(1, #p) == p then s = s:sub(#p + 1); again = true end
    end
  end
  again = true
  while again do
    again = false
    for _, p in ipairs(TRAILING) do
      if #s >= #p and s:sub(-#p) == p then s = s:sub(1, #s - #p); again = true end
    end
  end
  return s
end

local function check_str(s, holder, cell)
  if not cell then
    local tok = strip_ends(s)
    if MISSING[tok] then add(KIND_MISSING, tok, holder, s) end
  end
  if s:sub(1, 3) == ":::" then
    add(KIND_MARKUP, s, holder)
  elseif s:find("[^ \t\r\n{%]]{[#.]%a") then
    add(KIND_MARKUP, s, holder)
  elseif IN_QUARTO and s:find("\\@ref(", 1, true) then
    add(KIND_MARKUP, s, holder)
  end
end

local function is_literal(el)
  for _, c in ipairs(el.classes or {}) do
    if c == "weft-literal" then return true end
  end
  return false
end

local scan_blocks

local function scan_inlines(ins, holder, cell)
  for _, el in ipairs(ins) do
    local t = el.tag
    if t == "Str" then
      check_str(el.text, holder, cell)
    elseif t == "Strong" then
      local text = pandoc.utils.stringify(el)
      if IN_QUARTO and (text:match("^%?@%S+$") or text:match("^%?meta:%S+$") or text:match("^%?var:%S+$")) then
        add(KIND_REF, text, holder)
      else
        scan_inlines(el.content, holder, cell)
      end
    elseif t == "Span" then
      if not is_literal(el) then scan_inlines(el.content, holder, cell) end
    elseif t == "Note" then
      scan_blocks(el.content, false)
    elseif t == "Emph" or t == "Underline" or t == "Strikeout" or t == "Superscript" or t == "Subscript"
        or t == "SmallCaps" or t == "Quoted" or t == "Cite" or t == "Link" or t == "Image" then
      scan_inlines(el.content or el.caption, holder, cell)
    end
  end
end

local function scan_caption(cap, cell)
  if not cap then return end
  if cap.long then scan_blocks(cap.long, cell) end
end

local function scan_rows(rows, cell)
  for _, row in ipairs(rows or {}) do
    for _, c in ipairs(row.cells) do scan_blocks(c.contents, true) end
  end
end

scan_blocks = function(blocks, cell)
  for _, b in ipairs(blocks) do
    local t = b.tag
    if t == "Para" or t == "Plain" then
      scan_inlines(b.content, b.content, cell)
    elseif t == "Header" then
      S.section = b.identifier or ""
      scan_inlines(b.content, b.content, cell)
    elseif t == "LineBlock" then
      for _, line in ipairs(b.content) do scan_inlines(line, line, cell) end
    elseif t == "BulletList" or t == "OrderedList" then
      for _, item in ipairs(b.content) do scan_blocks(item, cell) end
    elseif t == "DefinitionList" then
      for _, item in ipairs(b.content) do
        scan_inlines(item[1], item[1], cell)
        for _, def in ipairs(item[2]) do scan_blocks(def, cell) end
      end
    elseif t == "BlockQuote" then
      scan_blocks(b.content, cell)
    elseif t == "Div" then
      if not is_literal(b) then scan_blocks(b.content, cell) end
    elseif t == "Figure" then
      scan_blocks(b.content, cell)
      scan_caption(b.caption, cell)
    elseif t == "Table" then
      scan_caption(b.caption, cell)
      scan_rows(b.head and b.head.rows, true)
      for _, body in ipairs(b.bodies or {}) do
        scan_rows(body.head, true)
        scan_rows(body.body, true)
      end
      scan_rows(b.foot and b.foot.rows, true)
    end
  end
end

-- ---- messages (E21 to E25) -----------------------------------------------------------------------

local function detail(f)
  if f.kind == KIND_REF then
    local id = f.text:match("^%?@(.+)$")
    if id then
      return string.format("Quarto could not resolve the reference `@%s`, and printed \"?@%s\" (rule 2.5.5).", id, id)
    end
    local key = f.text:sub(2)
    return string.format("the shortcode value `%s` was not found, and printed \"?%s\" (rule 2.5.5).", key, key)
  elseif f.kind == KIND_MISSING then
    return string.format("\"%s\" in the rendered prose: a value printed as missing. Mark a deliberate one [%s]{.weft-literal why=\"...\"} (rule 2.5.5).", f.text, f.text)
  end
  return string.format("\"%s\" in the rendered text: markup that Pandoc did not read (rule 2.5.5).", f.text)
end

local function json_line(f)
  local j = report.json_str
  return "{" .. table.concat({
    '"source":"output"', '"kind":' .. j(f.kind), '"level":' .. j(f.level), '"file":' .. j(S.file),
    '"format":' .. j(FORMAT), '"section":' .. j(f.section), '"text":' .. j(f.text),
    '"excerpt":' .. j(f.excerpt) }, ",") .. "}"
end

local function append_to(path, lines)
  local f = io.open(path, "a")
  if not f then return false end
  for _, l in ipairs(lines) do f:write(l, "\n") end
  f:close()
  return true
end

function Pandoc(doc)
  local ok_cwd, cwd = pcall(pandoc.system.get_working_directory)
  if not ok_cwd then cwd = nil end
  local path = source_path()
  if path then
    local d = path:gsub("[/\\]+[^/\\]*$", "")
    if d == path then d = "." end
    if cwd and d:sub(1, 1) ~= "/" then d = (cwd .. "/" .. d):gsub("/%./", "/"):gsub("/%.$", "") end
    MAIN_DIR = d
  elseif cwd then
    MAIN_DIR = cwd
  end
  local shown = path or "<unknown>"
  if cwd and shown:sub(1, #cwd + 1) == cwd .. "/" then shown = shown:sub(#cwd + 2) end
  S.file = (shown:gsub("^%./", ""))

  local text = path and read_file(path) or nil
  local cfg, problems = config.load(path, text, cwd)
  S.cfg = cfg

  scan_blocks(doc.blocks, false)

  local draft = truthy_env("WEFT_DRAFT") or cfg.draft == true
  local coll = nil
  if #S.found > 0 then coll = report.collect_path(dir_up_find, IN_QUARTO) end

  -- E33 for this filter's own settings, once: with the collection file open weft.lua has recorded it
  if not coll then
    for _, p in ipairs(problems) do
      if p.key == "output_refs" or p.key == "output_missing" or p.key == "output_markup" then
        io.stderr:write(string.format("%s: `%s: %s` is not a %s; the default is used (rule 9.1.6).\n",
                                      p.file, p.key, p.value, p.what))
      end
    end
  end

  if #S.found == 0 then return nil end

  local lines, fails = {}, 0
  for _, f in ipairs(S.found) do
    lines[#lines + 1] = json_line(f)
    if f.level == "fail" then fails = fails + 1 end
  end
  local logp = os.getenv("WEFT_OUTPUT_LOG")
  if logp and logp ~= "" then append_to(logp, lines) end

  if coll then
    if not append_to(coll, lines) then
      io.stderr:write("weft: cannot append to " .. coll .. "\n")
      if not draft and fails > 0 then os.exit(1) end
    end
    return nil
  end

  local out = { string.format("weft: %d problem%s in the rendered output of %s (%s)", #S.found,
                              #S.found == 1 and "" or "s", S.file, FORMAT) }
  for _, f in ipairs(S.found) do
    out[#out + 1] = string.format("  %s%s (%s)  [%s] %s", S.file, f.section ~= "" and (" #" .. f.section) or "",
                                  FORMAT, f.kind, f.text)
    out[#out + 1] = "      " .. f.excerpt
    out[#out + 1] = "    " .. detail(f)
  end
  io.stderr:write(table.concat(out, "\n"), "\n")
  if fails > 0 and not draft then os.exit(1) end
  return nil
end

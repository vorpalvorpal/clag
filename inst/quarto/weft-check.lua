-- weft-check.lua: the backstop filter of rule 2.5.3.
--
-- After knitting, fail the render on anything of weft's that survived:
--   * a span still carrying n, if, sign, cite or list (any letter case), or a weft
--     text class (.a .cap .strong .em)
--   * text that still shows an attribute block
--   * a code span carrying a weft class or key (a named value, which weft.lua resolves, says the
--     resolver filter is not installed, N94b)
--   * a code span with an attribute block whose text begins `r `, `R ` or
--     `{r}`, and any code span whose text begins `r `
--   * a leftover placeholder (private-use) character
--   * the marker text `<<weft:` (rule 2.9.5)
--
-- Self-contained: it reads only Pandoc's tree, so it works when the weft
-- package was never loaded and when the file was never knit (9.2.8).
--
-- Exit: os.exit(1) after reporting on stderr. Not in draft mode (WEFT_DRAFT,
-- or `draft: true` in _weft.yml, 9.4.3): the report is printed and the run
-- continues. When a collection file is in use (WEFT_COLLECT, or an open
-- .weft/failures.jsonl in the project, 2.6.6, 2.9.5) one JSON object per
-- finding is appended to it, and the filter does not exit.

local found = {}
local seen = {}

local KEYS = { n = true, ["if"] = true, sign = true, cite = true, list = true }
local RENDERER_KEYS = { digits = true, sigfig = true, sep = true, last = true, trunc = true, none = true }
local TEXT_CLASSES = { a = true, cap = true, strong = true, em = true }
local FORMATTER_CLASSES = {}
for c in ([[num pct sci p date no word count ord and or pairs range ul ol dl]]):gmatch("%S+") do
  FORMATTER_CLASSES[c] = true
end

local function excerpt(s)
  s = s:gsub("\0", ""):gsub("%s+", " ")
  if #s > 80 then s = s:sub(1, 77) .. "..." end
  return s
end

local function add(kind, what, text, bare)
  local key = kind .. "\0" .. what .. "\0" .. text
  if seen[key] then return end
  seen[key] = true
  found[#found + 1] = { kind = kind, what = what, text = text, bare = bare }
end

-- ---- helpers --------------------------------------------------------------

local function has_marker_in(s)
  return s:find("<<weft:", 1, true) ~= nil
end

local function has_placeholder(s)
  return s:find("\xEE[\x80-\xBF][\x80-\xBF]") ~= nil
      or s:find("\xEF[\x80-\xA3][\x80-\xBF]") ~= nil
end

-- An attribute block that was left behind touches the text before it
-- (`3{.num}`, rule 1.1.7): braces after a space, or at the start of the text,
-- are ordinary prose, and so is `]{...}` (an escaped bracket: a span that
-- was left as a span is found as one by check_span).
local function attr_block_shown(s)
  if s:find("[^%s{%]]{%s*%.[%a_]") then return true end
  local lower = s:lower()
  for k in pairs(KEYS) do
    if lower:find("[^%s{%]]{%s*" .. k .. "%s*=") then return true end
  end
  for k in pairs(RENDERER_KEYS) do
    if lower:find("[^%s{%]]{%s*" .. k .. "%s*=") then return true end
  end
  return false
end

local function has_attr(attr)
  return attr.identifier ~= "" or #attr.classes > 0 or #attr.attributes > 0
end

-- ---- element checks -------------------------------------------------------

local function check_span(el)
  for k, _ in pairs(el.attributes) do
    if KEYS[k:lower()] then
      add("leftover span", "a span still carries the key `" .. k .. "`",
          "[" .. excerpt(pandoc.utils.stringify(el.content)) .. "]{" .. k .. "=...}")
      return
    end
  end
  for _, c in ipairs(el.classes) do
    if TEXT_CLASSES[c] then
      add("leftover span", "a span still carries the text class `." .. c .. "`",
          "[" .. excerpt(pandoc.utils.stringify(el.content)) .. "]{." .. c .. "}")
      return
    end
  end
end

-- A NAME (N6): the text of a named value
local RESERVED = {}
for w in ([[TRUE FALSE True False true false NA NULL None nothing missing Inf NaN]]):gmatch("%S+") do
  RESERVED[w] = true
end
local function is_name(s)
  return #s <= 64 and s:match("^[A-Za-z_][A-Za-z0-9_.]*$") ~= nil and s:sub(-1) ~= "." and not RESERVED[s]
end

local E35 = "a named value was not resolved: the filter weft.lua is not installed before weft-check.lua (rule 2.5.3)."

local function check_code(el)
  local text = el.text
  local named = is_name(text)
  for _, c in ipairs(el.classes) do
    if FORMATTER_CLASSES[c] or TEXT_CLASSES[c] or c == "val" then
      if named then
        add("leftover code", E35, "`" .. excerpt(text) .. "`{." .. c .. "}", true)
      else
        add("leftover code", "a code span carries the weft class `." .. c .. "`",
            "`" .. excerpt(text) .. "`{." .. c .. "}")
      end
      return
    end
  end
  for k, _ in pairs(el.attributes) do
    local l = k:lower()
    if KEYS[l] or RENDERER_KEYS[l] then
      if named and RENDERER_KEYS[l] then
        add("leftover code", E35, "`" .. excerpt(text) .. "`{" .. k .. "=...}", true)
      else
        add("leftover code", "a code span carries the weft key `" .. k .. "`",
            "`" .. excerpt(text) .. "`{" .. k .. "=...}")
      end
      return
    end
  end
  local r_like = text:find("^[rR] ") or text:find("^{r}")
  if has_attr(el) and r_like then
    add("leftover code", "a code span with an attribute block holds R code that was not run",
        "`" .. excerpt(text) .. "`{...}")
  elseif text:find("^r ") then
    add("leftover code", "a code span holds R code that was not run",
        "`" .. excerpt(text) .. "`")
  end
end

-- the text of a list of inlines: its direct text only (nested elements are
-- visited on their own), in two forms. `plain` leaves out code, math and raw
-- text (what an author would see as prose); `all` has them in.
local function texts(inlines)
  local plain, all = {}, {}
  for _, el in ipairs(inlines) do
    local t = el.t
    local p, a
    if t == "Str" then p, a = el.text, el.text
    elseif t == "Space" or t == "SoftBreak" or t == "LineBreak" then p, a = " ", " "
    elseif t == "Quoted" then p, a = '"', '"'
    elseif t == "Code" or t == "RawInline" or t == "Math" then p, a = "\0", el.text
    else p, a = "\0", "\0" end
    plain[#plain + 1] = p
    all[#all + 1] = a
  end
  return table.concat(plain), table.concat(all)
end

local function check_marker_text(all)
  if has_marker_in(all) then
    for body in all:gmatch("<<weft:%s*([^>]*)>*") do
      add("marker", "the marker `<<weft: " .. excerpt(body) .. ">>` is in the text", body)
    end
    if not all:find("<<weft:%s*[^>]*>") then
      add("marker", "the text `<<weft:` is in the document", "<<weft:")
    end
  end
end

-- A code block is chunk output (a block with no language class, or with a
-- `cell-output` class) or a fenced block that shows code on purpose (it
-- carries a language class): only chunk output is looked in (2.9.5, 1.9.2).
local function check_codeblock(el)
  local classes = el.classes or {}
  local output = #classes == 0
  for _, c in ipairs(classes) do
    if c == "cell-output" or c:find("^cell%-output%-") then output = true end
  end
  if output then check_marker_text(el.text) end
end

local function check_inlines(inlines)
  local plain, all = texts(inlines)
  check_marker_text(all)
  if has_placeholder(all) then
    add("placeholder", "a placeholder character is left in the text", excerpt(all))
  end
  if attr_block_shown(plain) then
    add("leftover attribute block", "text still shows an attribute block", excerpt(plain))
  end
end

-- ---- draft mode and collection --------------------------------------------

local function truthy(v)
  if v == nil then return false end
  -- `true` and `false` only (9.4.3); the knit has already refused anything else
  v = v:gsub("^[\"']", ""):gsub("[\"']$", ""):lower()
  return v == "true"
end

local function dir_of(path)
  return (path:gsub("[/\\]+[^/\\]*$", ""))
end

local function start_dirs()
  local dirs = {}
  local ok, cwd = pcall(function() return pandoc.system.get_working_directory() end)
  if ok and cwd then dirs[#dirs + 1] = cwd end
  local inputs = PANDOC_STATE and PANDOC_STATE.input_files
  if inputs and inputs[1] and inputs[1] ~= "" and inputs[1] ~= "-" then
    local d = dir_of(inputs[1])
    if d == inputs[1] then d = "." end
    dirs[#dirs + 1] = d
  end
  return dirs
end

-- find `rel` in a directory or a parent of it (at most 8 levels)
local function find_upward(rel)
  for _, d in ipairs(start_dirs()) do
    local cur = d
    for _ = 1, 8 do
      local p = cur .. "/" .. rel
      local f = io.open(p, "r")
      if f then return f, p end
      local parent = dir_of(cur)
      if parent == cur or parent == "" then break end
      cur = parent
    end
  end
  return nil
end

local function draft_mode()
  local ev = os.getenv("WEFT_DRAFT")
  if ev ~= nil and (ev:lower() == "1" or truthy(ev)) then return true end
  local f = find_upward("_weft.yml")
  if not f then return false end
  local draft = false
  for line in f:lines() do
    local v = line:match("^draft:%s*([^#%s]*)")
    if v then draft = truthy(v) end
  end
  f:close()
  return draft
end

-- The open collection file of this project render. A file left behind by a
-- render that stopped is not in use: the filter finds one only inside a Quarto
-- render, and only when the run it names (its first line) is the one in
-- .weft/run, or, with no .weft/run, when that run started under an hour ago
-- (the id begins with its time).
local function collect_path()
  local p = os.getenv("WEFT_COLLECT")
  if p and p ~= "" then return p end
  if quarto == nil then return nil end
  local f, path = find_upward(".weft/failures.jsonl")
  if not f then return nil end
  local first = f:read("l") or ""
  f:close()
  local mine = first:match('"run"%s*:%s*"([^"]*)"')
  local rf = find_upward(".weft/run")
  local id = nil
  if rf then id = rf:read("l"); rf:close() end
  if id and id ~= "" then
    if mine ~= id then return nil end
  elseif mine then
    local y, mo, d, h, mi, sec = mine:match("^(%d%d%d%d)(%d%d)(%d%d)T(%d%d)(%d%d)(%d%d)")
    if y then
      local t = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                          hour = tonumber(h), min = tonumber(mi), sec = tonumber(sec) })
      if os.time() - t > 3600 then return nil end
    end
  end
  return path
end

local function json_str(s)
  local out = {}
  local ok = pcall(function()
    for _, cp in utf8.codes(s) do
      if cp == 34 then out[#out + 1] = '\\"'
      elseif cp == 92 then out[#out + 1] = "\\\\"
      elseif cp == 10 then out[#out + 1] = "\\n"
      elseif cp == 13 then out[#out + 1] = "\\r"
      elseif cp == 9 then out[#out + 1] = "\\t"
      elseif cp < 32 or cp > 126 then
        if cp > 0xFFFF then
          cp = cp - 0x10000
          out[#out + 1] = string.format("\\u%04x\\u%04x", 0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF))
        else
          out[#out + 1] = string.format("\\u%04x", cp)
        end
      else out[#out + 1] = string.char(cp) end
    end
  end)
  if not ok then return '"(unreadable text)"' end
  return '"' .. table.concat(out) .. '"'
end

local function json_line(item, file)
  local kind, line, chunk = item.kind, nil, nil
  if item.kind == "marker" then
    kind = item.text:match("^%s*([^,>]-)%s*,") or item.text:match("^%s*([^>]-)%s*$") or "marker"
    line = item.text:match("line%s+(%d+)")
    chunk = item.text:match("chunk%s+([^%s>,]+)")
  end
  local parts = {
    '"source":"filter"',
    '"kind":' .. json_str(kind),
    '"file":' .. (file and json_str(file) or "null"),
    '"line":' .. (line or "null"),
    '"chunk":' .. (chunk and json_str(chunk) or "null"),
    '"message":' .. json_str(item.what),
    '"text":' .. json_str(item.text),
  }
  return "{" .. table.concat(parts, ",") .. "}"
end

-- ---- run ------------------------------------------------------------------

local function is_marker(el)
  return el.classes:includes("weft-marker")
end

function Pandoc(full)
  -- N94a: a span.weft-marker is unwrapped, and the marker text inside it is not reported
  local unwrapped, n_markers = nil, 0
  local function count(el) if is_marker(el) then n_markers = n_markers + 1 end end
  full:walk({ Span = count })
  pandoc.Pandoc({}, full.meta):walk({ Span = count })
  local doc = full
  if n_markers > 0 then
    unwrapped = full:walk({ Span = function(el) if is_marker(el) then return el.content end end })
    doc = full:walk({ Span = function(el) if is_marker(el) then return {} end end })
  end
  local function result()
    if unwrapped then return unwrapped end
    return nil
  end
  doc:walk({
    Inlines = function(inlines) check_inlines(inlines) end,
    Span = function(el) check_span(el) end,
    Code = function(el) check_code(el) end,
    CodeBlock = function(el) check_codeblock(el) end,
  })
  -- the metadata (title and the rest) carries inlines too
  pcall(function()
    pandoc.Pandoc({}, doc.meta):walk({
      Inlines = function(inlines) check_inlines(inlines) end,
      Span = function(el) check_span(el) end,
      Code = function(el) check_code(el) end,
    })
  end)

  if #found == 0 then return result() end

  local inputs = PANDOC_STATE and PANDOC_STATE.input_files
  local file = inputs and inputs[1]
  if file == "" or file == "-" then file = nil end
  -- under Quarto the Pandoc input is a temporary file; the source is better
  if quarto and quarto.doc and quarto.doc.input_file then
    file = quarto.doc.input_file
  end

  local coll = collect_path()
  local draft = draft_mode()

  local lines = {}
  for _, it in ipairs(found) do
    lines[#lines + 1] = "  - " .. it.what .. (it.bare and " " or ": ") .. it.text
  end
  io.stderr:write(string.format("\nweft-check: %d leftover weft %s%s%s\n%s\n",
    #found, #found == 1 and "construct" or "constructs",
    file and (" in " .. file) or "",
    (coll and " (collected)") or (draft and " (draft mode)") or "",
    table.concat(lines, "\n")))

  if coll then
    local f = io.open(coll, "a")
    if f then
      for _, it in ipairs(found) do f:write(json_line(it, file), "\n") end
      f:close()
    else
      io.stderr:write("weft-check: cannot append to " .. coll .. "\n")
      if not draft then os.exit(1) end
    end
    return result()
  end
  if draft then return result() end
  io.stderr:write("weft-check: the render fails (set WEFT_DRAFT=1 to report instead).\n")
  os.exit(1)
end

-- weft.lua: the resolver filter (dev/design-6.md, package 6c).
--
-- Code publishes typed values by name (a fenced `weft-values` block); prose refers to the names;
-- this filter resolves the constructs on Pandoc's tree, in document order:
--   `NAME`{.num} `NAME`{.pct} `NAME`{.val} ...      a named value (N5)
--   [yes | no]{if="a > 1, b"}                       a condition (N9 to N11)
--   [# site | # sites]{n="NAME"}                    a plural (1.5.1)
-- It then reports every failure once, on stderr, in the layout of weft-post-render.R, and exits
-- 1 unless in draft mode or with a collection file open (N86). weft-check.lua runs after it.
--
-- Pure Lua 5.4 and plain Pandoc (3.1 or later): no Quarto API. The modules in weftlib/ are loaded
-- from the folder beside this file (PANDOC_SCRIPT_FILE), so the same files run under Quarto,
-- under rmarkdown (pandoc_args) and under plain Pandoc.
--
-- Later packages add to the two tables below: CLASSES (6f: .sci .p words, collapse, text) and
-- GOVERNORS (6f: sign, list; 6c: if, n).

local HERE = pandoc.path.directory(PANDOC_SCRIPT_FILE or "")
if HERE == "" then HERE = "." end

local function version_ok()
  local v = PANDOC_VERSION
  if not v then return false end
  return v[1] > 3 or (v[1] == 3 and (v[2] or 0) >= 1)
end

local function truthy_env(name)
  local v = os.getenv(name)
  if v == nil then return false end
  v = v:lower()
  return v == "1" or v == "true"
end

if not version_ok() then
  function Pandoc(doc)
    io.stderr:write(string.format("weft.lua needs Pandoc 3.1 or later; this is Pandoc %s.\n",
                                  tostring(PANDOC_VERSION)))
    if not truthy_env("WEFT_DRAFT") then os.exit(1) end
    return nil
  end
  return
end

local function lib(name) return dofile(HERE .. "/weftlib/" .. name .. ".lua") end
local num = lib("num")
local cond = lib("cond")
local config = lib("config")
local lines_lib = lib("lines")
local report = lib("report")
local words = lib("words")
local stamp = lib("stamp")
local ledger = lib("ledger")

-- ---- what weft owns -----------------------------------------------------------------------------

-- every class weft owns, with its at-most-one group; `val` is the filter's own
local CLASSES = {}
for _, c in ipairs({ "num", "pct", "sci", "p", "date", "val" }) do CLASSES[c] = { group = "number" } end
for _, c in ipairs({ "word", "count", "ord" }) do CLASSES[c] = { group = "wording" } end
CLASSES["no"] = { group = "no" }
for _, c in ipairs({ "and", "or", "pairs", "range", "ul", "ol", "dl" }) do CLASSES[c] = { group = "collapse" } end
for _, c in ipairs({ "uname", "usym", "nounit" }) do CLASSES[c] = { group = "unit" } end
CLASSES["plus"] = { group = "plus" }
CLASSES["a"] = { group = "a" }
CLASSES["cap"] = { group = "cap" }
CLASSES["strong"] = { group = "emphasis" }
CLASSES["em"] = { group = "emphasis" }

-- the governor keys, and the keys weft owns on a construct
local GOVERNORS = { ["if"] = true, n = true, sign = true, list = true, cite = true }
-- `unit` is a renderer key (N5, 6d): the filter has no units, so a named value with it fails (E20)
local RENDERER_KEYS = { digits = true, sigfig = true, sep = true, last = true, trunc = true, none = true,
                        unit = true, label = true }
local OWNED_KEYS = { unit = true, level = true, decision = true, ["weft-at"] = true, ["weft-cap"] = true }
for k in pairs(GOVERNORS) do OWNED_KEYS[k] = true end
for k in pairs(RENDERER_KEYS) do OWNED_KEYS[k] = true end

local GROUP_ORDER = { "number", "wording", "collapse", "unit", "emphasis" }
local WORDING_WITH_VAL = { no = true, word = true, count = true, ord = true }

-- the classes this filter implements (6c): the printers for a named value
local IMPLEMENTED = {}
for cl in pairs(CLASSES) do IMPLEMENTED[cl] = true end
local IMPLEMENTED_KEYS = { digits = true, sigfig = true, sep = true, last = true, trunc = true, none = true,
                           label = true }

-- ---- state --------------------------------------------------------------------------------------

local S = {
  values = {}, valid = {}, fails = {}, warned = {}, cfg = nil, src = nil, main = nil,
  stash = {}, mute = 0, minus_used = false, stale = nil, lang = nil, ids = {}, id_log = {},
  -- 6g: the ledger entries, the construct being resolved, where we are, the blocks read, N92
  entries = {}, frame = nil, cdepth = 0, section = "", context = "prose",
  nblocks = 0, any_stale = false, oldest_at = nil, knitr = false,
}

local function with(ctx, k, v)
  local c = {}
  for a, b in pairs(ctx) do c[a] = b end
  c[k] = v
  return c
end

local function is_space(el) return el ~= nil and (el.t == "Space" or el.t == "SoftBreak") end

-- ---- locations and failures -----------------------------------------------------------------------

-- a path as shown: relative to the working folder when it is under it
local function shown_path(p)
  if S.cwd and p:sub(1, #S.cwd + 1) == S.cwd .. "/" then p = p:sub(#S.cwd + 2) end
  return (p:gsub("^%./", ""))
end

local function file_of(idx)
  if S.src and idx and S.src.files[idx] then return shown_path(S.src.files[idx]) end
  return S.main
end

local function at_of(el)
  local a = el.attributes and el.attributes["weft-at"]
  if a then
    local i, l = a:match("^(%d+):(%d+)$")
    if i then return tonumber(i), tonumber(l) end
  end
  return nil, nil
end

-- info: where a construct is: {shown, idx, line, chunk}
local function info_of(el, ctx, shown)
  local idx, line = at_of(el)
  return { shown = shown, idx = idx, line = line, chunk = ctx.cell }
end

local function marker(kind, info)
  local where = ""
  if info.line then where = ", line " .. info.line
  elseif info.chunk then where = ", chunk " .. info.chunk end
  return pandoc.Span({ pandoc.Str("<<weft: " .. kind .. where .. ">>") }, pandoc.Attr("", { "weft-marker" }))
end

local function record(list, kind, info, detail, hint)
  if S.mute > 0 then return end
  list[#list + 1] = {
    kind = kind, file = file_of(info.idx), line = info.line, chunk = info.chunk,
    expr = info.shown, detail = detail, hint = hint, _info = info,
  }
end

-- a failure of the construct: collected, and a marker in its place
local function fail(kind, info, detail, hint)
  record(S.fails, kind, info, detail, hint)
  return marker(kind, info)
end

local function warn(kind, info, detail)
  record(S.warned, kind, info, detail)
end

-- ---- records ------------------------------------------------------------------------------------

local function is_array(t)
  return type(t) == "table" and (getmetatable(t) ~= nil or next(t) == nil or t[1] ~= nil)
end

local NUMBER_PATTERNS = { "^%-?%d+%.%d+$", "^%-?%d+$", "^%-?%d+[eE][+-]?%d+$", "^%-?%d+%.%d+[eE][+-]?%d+$" }
local function number_text(v)
  if type(v) ~= "string" then return false end
  for _, p in ipairs(NUMBER_PATTERNS) do if v:match(p) then return true end end
  return false
end

local valid_date = cond.valid_date

-- nil when a scalar record reads, else what is wrong
local function scalar_problem(r)
  if type(r) ~= "table" then return "it is not an object" end
  local t = r.t
  if t == "bool" then
    if type(r.v) ~= "boolean" then return "`v` of a bool is not true or false" end
  elseif t == "int" then
    if type(r.v) ~= "string" or not (r.v:match("^%-?0$") or r.v:match("^%-?[1-9]%d*$")) then
      return "`v` of an int is not a string of digits"
    end
  elseif t == "float" or t == "decimal" then
    if not number_text(r.v) then return "`v` of a " .. t .. " is not a number as text" end
  elseif t == "string" then
    if type(r.v) ~= "string" then return "`v` of a string is not a string" end
  elseif t == "date" then
    if not valid_date(r.v) then return "`v` of a date is not a YYYY-MM-DD date" end
  elseif t == "missing" or t == "error" then
    if r.why ~= nil and r.why ~= pandoc.json.null and type(r.why) ~= "string" then
      return "`why` is not a string"
    end
  else
    return "the kind `" .. tostring(t) .. "` is not known"
  end
  return nil
end

-- nil when a `checks` member is an array of well-formed check objects, else what is wrong (N22, N23)
local LEVELS = { fail = true, warn = true }
local function checks_problem(ch)
  if ch == nil or ch == pandoc.json.null then return nil end
  if type(ch) ~= "table" or not is_array(ch) then return "`checks` is not an array" end
  for i = 1, #ch do
    local c = ch[i]
    if type(c) ~= "table" or is_array(c) and next(c) ~= nil then return "check " .. i .. " is not an object" end
    if type(c.text) ~= "string" then return "check " .. i .. " has no `text` string" end
    -- `ok: null` is a check that could not be evaluated, and fails like a false one (N25a)
    if type(c.ok) ~= "boolean" and c.ok ~= pandoc.json.null then
      return "`ok` of check " .. i .. " is not true, false or null"
    end
    if c.level ~= nil and c.level ~= pandoc.json.null and not (type(c.level) == "string" and LEVELS[c.level]) then
      return "`level` of check " .. i .. " is not \"fail\" or \"warn\""
    end
    if c.why ~= nil and c.why ~= pandoc.json.null and type(c.why) ~= "string" then
      return "`why` of check " .. i .. " is not a string"
    end
  end
  return nil
end

local function record_problem(r)
  if type(r) ~= "table" then return "it is not an object" end
  local cp = checks_problem(r.checks)
  if cp then return cp end
  if r.t == "list" then
    if type(r.v) ~= "table" or not is_array(r.v) then return "`v` of a list is not an array" end
    for i = 1, #r.v do
      local e = r.v[i]
      if type(e) == "table" and e.t == "list" then return "a list holds a list" end
      local p = scalar_problem(e)
      if p then return "element " .. i .. ": " .. p end
    end
    return nil
  end
  return scalar_problem(r)
end

-- the record of a name as the filter reads it: a broken one is an error record (E31)
local function record_of(name)
  local r = S.valid[name]
  if r then return r end
  local raw = S.values[name]
  if raw == nil then return nil end
  local problem = record_problem(raw)
  if problem then
    r = { t = "error", why = string.format("the record of `%s` does not read: %s (rule 2.13.1).", name, problem) }
  elseif raw.t == "list" and #raw.v == 1 and raw.v[1].t ~= "missing" and raw.v[1].t ~= "error" then
    -- N47 (6R): a vector of length 1 is a list of one with its key. The filter prints it as its element
    -- under any class; `_keys` keeps the name for `.pairs` and `.dl`.
    r = {}
    for k, v in pairs(raw.v[1]) do r[k] = v end
    r.checks = raw.checks
    local keys = raw.keys
    if type(keys) == "table" and keys ~= pandoc.json.null and #keys == 1 and type(keys[1]) == "string" then
      r._keys = keys
    end
  else
    r = raw
  end
  S.valid[name] = r
  return r
end

local function kind_name(r) return cond.kind_name(r.t) end

-- A float's text in one form, whatever the writer wrote (1.12.2, N8): the shortest digits, no trailing `.0`,
-- fixed notation for a decimal exponent from -4 to 14 and the exponent form of R (`1e+23`, `5e-324`) outside.
local function float_text(v)
  local neg = v:sub(1, 1) == "-"
  local s = neg and v:sub(2) or v
  local mant, ex = s:match("^([0-9.]+)[eE]([-+]?[0-9]+)$")
  if not mant then mant, ex = s, "0" end
  local ip, fp = mant:match("^([0-9]*)%.?([0-9]*)$")
  if not ip then return v end
  local digits = (ip .. fp):gsub("^0+", "")
  local e10 = (math.tointeger(tonumber(ex)) or 0) - #fp
  if digits == "" then return neg and "-0" or "0" end
  local trimmed = digits:gsub("0+$", "")
  e10 = e10 + (#digits - #trimmed)
  digits = trimmed
  local k = #digits
  local x = e10 + k - 1
  local out
  if x >= 15 or x < -4 then
    out = digits:sub(1, 1) .. (k > 1 and ("." .. digits:sub(2)) or "")
    out = out .. string.format("e%s%02d", x < 0 and "-" or "+", math.abs(x))
  elseif e10 >= 0 then
    out = digits .. string.rep("0", e10)
  elseif -e10 >= k then
    out = "0." .. string.rep("0", -e10 - k) .. digits
  else
    out = digits:sub(1, k + e10) .. "." .. digits:sub(k + e10 + 1)
  end
  return (neg and "-" or "") .. out
end

local function scalar_text(r)
  if r.t == "bool" then return r.v and "true" or "false" end
  if r.t == "float" and type(r.v) == "string" then return float_text(r.v) end
  return tostring(r.v)
end

-- a record's text as `.val` prints it; nil and a reason when an element is missing
local function val_text(r)
  if r.t == "list" then
    local items = {}
    for i = 1, #r.v do
      local e = r.v[i]
      if e.t == "missing" or e.t == "error" then return nil, "element " .. i .. " is missing" end
      items[i] = scalar_text(e)
    end
    return table.concat(items, ", ")
  end
  return scalar_text(r)
end

local function why_of(r)
  local w = r.why
  if w == nil or w == pandoc.json.null then return "" end
  return tostring(w)
end

-- a failure table when the name has no usable value
local function lookup(name)
  local forward = false
  if S.values[name] == nil then
    local fw = S.fwd and S.fwd[name]
    if fw == nil then
      return nil, {
        kind = "no value",
        detail = string.format("no value is published under the name `%s` in this document (rule 1.12.7).", name),
        hint = string.format(
          "Publish it in code in this document: weft_put(%s = ...) in R, put(%s=...) in Python, @put %s in Julia. "
          .. "A cell with include: false or output: false publishes nothing on the jupyter and julia engines.",
          name, name, name),
      }
    end
    if fw.n > 1 then
      return nil, {
        kind = "no value",
        detail = string.format(
          "`%s` is used above its first publication, and the document publishes %d different values for it below; "
          .. "a use above every publication needs a name that takes one value (rule 1.12.7).", name, fw.n),
        hint = "Move the sentence below the value it means, or publish that value under a name of its own.",
      }
    end
    -- N90, N92: the one value the document publishes below, the last publication's record
    S.values[name] = fw.last
    S.valid[name] = nil
    forward = true
  end
  local r = record_of(name)
  if forward then S.values[name] = nil; S.valid[name] = nil end
  if r.t == "missing" then
    return nil, { kind = "no value", detail = string.format("`%s` is missing (%s) (rule 1.3.4).", name, why_of(r)) }
  elseif r.t == "error" then
    return nil, { kind = "value error", detail = (why_of(r):gsub("{S}", "`" .. name .. "`")) }
  end
  return r
end

-- the checks a record carries count where it is used (N25a): a failed check is a failed claim, a
-- warned one a warned check. Returns the markers of the failed ones.
local function run_checks(rec, info)
  local markers = {}
  local checks = rec.checks
  if type(checks) ~= "table" then return markers end
  for _, c in ipairs(checks) do
    if c.ok ~= true then
      local text = val_text(rec) or "?"
      local detail = string.format("%s was false (value %s)", tostring(c.text), text)
      if type(c.why) == "string" then detail = detail .. "; " .. c.why end
      if c.level == "warn" then
        warn("failed claim", info, detail)
      else
        markers[#markers + 1] = fail("failed claim", info, detail)
      end
    end
  end
  return markers
end

-- ---- reading a block ------------------------------------------------------------------------------

local function dir_up_find(rel)
  local starts = {}
  local ok, cwd = pcall(pandoc.system.get_working_directory)
  if ok and cwd then starts[#starts + 1] = cwd end
  if S.main_dir then starts[#starts + 1] = S.main_dir end
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

-- N91, N48: `.weft/run` in the document's folder or one of its 8 parents, else WEFT_RUN
local function current_run()
  local f = dir_up_find(".weft/run")
  if f then
    local l = f:read("l")
    f:close()
    if l and l ~= "" then return l end
  end
  local e = os.getenv("WEFT_RUN")
  if e and e ~= "" then return e end
  return nil
end

local function block_failure(el, ctx, detail)
  local info = { shown = nil, chunk = ctx.cell }
  info.shown = "a weft-values block"
  record(S.fails, "construct error", info, detail)
end

-- set below, once the path helpers exist: a values file's text by its path as written, or nil and why (N30)
local values_file_text

-- the decoded block, or nil and the failure's text (the main pass reports it; the pre-pass, N90, ignores it)
local function parse_block(el)
  local text = el.text
  local from_file = el.attributes["file"]
  local fpath = from_file
  if from_file then
    local reason
    if text:find("[^ \t\r\n]") then
      reason = "the block has a body, and a block with `file=` must be empty"
    else
      text, reason = values_file_text(fpath)
    end
    if not text then
      return nil, string.format("the values file %s cannot be read: %s (rule 2.13.10).", fpath, reason)
    end
  end
  if #text > 5000000 then
    if from_file then
      return nil, string.format("the values file %s cannot be read: %d bytes, and the limit is 5000000 (rule 2.13.10).", fpath, #text)
    end
    return nil, string.format("a weft-values block of %d bytes; the limit is 5000000 (rule 2.13.1).", #text)
  end
  local ok, d = pcall(pandoc.json.decode, text, false)
  local function bad(reason)
    if from_file then
      return nil, string.format("the values file %s cannot be read: %s (rule 2.13.10).", fpath, reason)
    end
    return nil, string.format("a weft-values block that does not read: %s (rule 2.13.1).", reason)
  end
  if not ok or d == nil or d == pandoc.json.null then return bad("not JSON") end
  if type(d) ~= "table" or getmetatable(d) ~= nil then return bad("not a JSON object") end
  if type(d.weft) ~= "number" or d.weft ~= 1 then return bad("`weft` is not 1") end
  if type(d.values) ~= "table" or getmetatable(d.values) ~= nil then return bad("no `values` object") end
  local bp = checks_problem(d.checks)
  if bp then return bad(bp) end
  local names = {}
  for k in pairs(d.values) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do
    if not cond.is_name(k) then return bad(string.format("`%s` in `values` is not a name", k)) end
  end
  return d, nil, names, from_file
end

local function read_block(el, ctx)
  local d, reason, names, from_file = parse_block(el)
  if not d then
    block_failure(el, ctx, reason)
    return
  end
  for _, k in ipairs(names) do
    S.values[k] = d.values[k]
    S.valid[k] = nil
  end
  -- freshness (N91, N110): an inline block only. A values file is computed before the render, by design (a
  -- `targets` pipeline), so its own run is not compared with this one (review 6, #7)
  if not from_file then
    local now = S.current_run
    if now == nil then S.current_run = current_run() or false; now = S.current_run end
    S.nblocks = S.nblocks + 1
    if type(d.at) == "number" and (S.oldest_at == nil or d.at < S.oldest_at) then S.oldest_at = d.at end
    if now and d.run ~= now then S.any_stale = true end
    if now and S.stale == nil then
      local run = d.run
      if run ~= now then S.stale = { run = (type(run) == "string") and run or "null", current = now } end
    end
  end
  -- the block's own checks (N25b)
  if type(d.checks) == "table" then
    for _, c in ipairs(d.checks) do
      if type(c) == "table" and c.ok ~= true then
        local line = type(c.line) == "number" and math.tointeger(c.line) or nil
        local rec = type(c.value) == "table" and not record_problem(c.value) and c.value or nil
        local val = rec and val_text(rec) or "?"
        local detail = string.format("%s was false (value %s)", tostring(c.text), val)
        if type(c.why) == "string" then detail = detail .. "; " .. c.why end
        local info = { shown = (type(c.expr) == "string" and c.expr) or tostring(c.text), line = line,
                       chunk = (not line) and ctx.cell or nil }
        info.idx = nil
        record(c.level == "warn" and S.warned or S.fails, "failed claim", info, detail)
      end
    end
  end
end

-- ---- the construct as shown (N87) ---------------------------------------------------------------

local function shown_attrs(el)
  local parts = {}
  if el.identifier and el.identifier ~= "" then parts[#parts + 1] = "#" .. el.identifier end
  for _, c in ipairs(el.classes) do parts[#parts + 1] = "." .. c end
  for k, v in pairs(el.attributes) do
    if k ~= "weft-at" and k ~= "weft-cap" then parts[#parts + 1] = string.format('%s="%s"', k, v) end
  end
  return table.concat(parts, " ")
end

local function shown_code(el)
  return "`" .. el.text .. "`{" .. shown_attrs(el) .. "}"
end

local function cut(s, n)
  if utf8.len(s) and utf8.len(s) > n then return s:sub(1, utf8.offset(s, n + 1) - 1) .. "..." end
  return s
end

local function shown_span(el, key, value)
  local text = pandoc.utils.stringify(el.content):gsub("[ \t\r\n]+", " ")
  text = text:gsub("^ ", ""):gsub(" $", "")
  return string.format('[%s]{%s="%s"}', cut(text, 60), key, value)
end

-- ---- named values (N5 to N8, N17, N82, N83, N100) ---------------------------------------------------

local function is_weft_class(c) return CLASSES[c] ~= nil or S.cfg.formatters[c] == true end

local function code_candidate(el)
  local has_class, has_key = false, false
  for _, c in ipairs(el.classes) do if is_weft_class(c) then has_class = true end end
  for k in pairs(el.attributes) do
    -- `label` alone is no renderer key: it does not make a code span a named value (N24)
    if RENDERER_KEYS[k:lower()] and k:lower() ~= "label" then has_key = true end
    -- N101: a decision on a name is a named value with a key that does not belong (E51)
    if k:lower() == "decision" and cond.is_name(el.text) then has_key = true end
  end
  if not (has_class or has_key) then return false end
  if cond.is_name(el.text) then return true end
  local r_like = el.text:find("^[rR] ") or el.text:find("^{r}")
  return has_class and not r_like
end

local function whole_number(text)
  local n = tonumber(text)
  if n == nil or text:match("[^%d%-%+eE%.]") or n ~= math.floor(n) then return nil end
  return n
end

local TEXT_CLASS = { a = true, cap = true, strong = true, em = true }
local NUMBER_STAGE = { "num", "pct", "sci", "p", "date", "val" }
local WORDING_STAGE = { "word", "count", "ord" }
local COLLAPSE_STAGE = { "and", "or", "pairs", "range", "ul", "ol", "dl" }
local ENGLISH_ONLY = { "no", "word", "count", "ord", "and", "or", "pairs", "range", "a", "date", "uname" }
local LIST_CLASS = { ul = true, ol = true, dl = true }

-- ---- failures raised inside the formatters ---------------------------------------------------------

-- Quarto redefines the global `error` to log and return, so a failure is raised with assert(), which it
-- leaves alone.
local function raise(kind, detail, hint) assert(false, { kind = kind, detail = detail, hint = hint }) end
local function vfail(detail) raise("value error", detail) end
local function cfail(detail) raise("construct error", detail) end
local function nofail(detail) raise("no value", detail) end

-- the failure table of anything pcall caught: a Lua error that is not ours is a value error
local function caught(e)
  if type(e) == "table" and e.kind then return e end
  return { kind = "value error", detail = type(e) == "table" and tostring(e.detail) or tostring(e) }
end

-- run fn(); a failure becomes the marker of the construct
local function guarded(info, fn)
  local ok, res, extra = pcall(fn)
  if ok then return res, extra end
  local f = caught(res)
  return pandoc.Inlines({ fail(f.kind, info, f.detail, f.hint) })
end

local function need(name)
  local rec, f = lookup(name)
  if not rec then raise(f.kind, f.detail, f.hint) end
  return rec
end

-- ---- markdown text to inlines ----------------------------------------------------------------------

local SPECIAL = "[%*_%^~%[%]`<>\\&#%$@|{}!=\t\r\n]"
local SPECIAL_DATA = "[%*_%^~%[%]`<>\\&#%$@|{}!\"'=\t\r\n]"

-- Formatter output is markdown (1.4.10). Text with nothing in it for markdown to read is split at its
-- single spaces; anything else goes through Pandoc's reader.
-- `data` says the text may hold text from data, where a quote is read as typography (smart quotes); the
-- text of a number is not read so: its marks are the configuration's.
local function md_inlines(text, data)
  local out = pandoc.Inlines({})
  if text == "" then return out end
  if not text:find(data and SPECIAL_DATA or SPECIAL) and not (data and (text:find("%-%-") or text:find("%.%.%.")))
     and not text:find("^[%-+] ")
     and not text:find("^%d+[%.)] ") and not text:find("  ", 1, true) and text:sub(1, 1) ~= " "
     and text:sub(-1) ~= " " then
    local first = true
    for piece in text:gmatch("[^ ]+") do
      if not first then out:insert(pandoc.Space()) end
      out:insert(pandoc.Str(piece))
      first = false
    end
    return out
  end
  -- a leading ">" (a p-value with no label) would be read as a block quote
  if text:sub(1, 1) == ">" then text = "\\" .. text end
  local doc = pandoc.read(text, "markdown")
  return pandoc.Inlines(pandoc.utils.blocks_to_inlines(doc.blocks))
end

local function md_blocks(text) return pandoc.read(text, "markdown").blocks end

-- ---- text classes on inlines (stage iv; 1.1.9) ---------------------------------------------------------

local function cap_first(inls)
  local out, done = pandoc.Inlines({}), false
  for _, el in ipairs(inls) do
    if not done and el.t == "Str" then
      local lead = #el.text:match("^[^%w]*")
      if lead < #el.text then
        out:insert(pandoc.Str(words.capitalise(el.text)))
        done = true
      else
        out:insert(el)
      end
    elseif not done and el.content ~= nil and type(el.content) == "table" and el.t ~= "Note"
           and el.t ~= "Cite" and el.t ~= "Math" then
      local inner, d2 = cap_first(el.content)
      local copy = el:clone()
      copy.content = inner
      out:insert(copy)
      done = d2
    else
      out:insert(el)
    end
  end
  return out, done
end

-- `.a`, `.cap`, `.em`, `.strong`, in the order of 1.4.1; an empty text stays empty
local function text_inlines(inls, has)
  if #inls == 0 then return inls end
  if not (has.a or has.cap or has.em or has.strong) then return inls end
  local cfg = S.cfg
  if has.a then
    local vowel, msg = words.vowel_sound(pandoc.utils.stringify(inls), cfg.minus, cfg.decimal_mark, cfg.big_mark)
    if vowel == nil then vfail(msg) end
    local lead = pandoc.Inlines({ pandoc.Str(vowel and "an" or "a"), pandoc.Space() })
    lead:extend(inls)
    inls = lead
  end
  if has.cap then inls = cap_first(inls) end
  if has.em then inls = pandoc.Inlines({ pandoc.Emph(inls) }) end
  if has.strong then inls = pandoc.Inlines({ pandoc.Strong(inls) }) end
  return inls
end

-- the same stage on a string of markdown
local function text_stage(text, has)
  if text == "" then return text end
  local cfg = S.cfg
  if has.a then
    local vowel, msg = words.vowel_sound(text, cfg.minus, cfg.decimal_mark, cfg.big_mark)
    if vowel == nil then vfail(msg) end
    text = (vowel and "an " or "a ") .. text
  end
  if has.cap then text = words.capitalise(text) end
  if has.em then text = "*" .. text .. "*" end
  if has.strong then text = "**" .. text .. "**" end
  return text
end

-- ---- the construct's classes and keys --------------------------------------------------------------------

-- the construct's own classes and keys; returns a failure (kind, detail) or nil
local PLUS_CLASH = { sci = true, p = true, date = true, no = true, word = true, count = true, ord = true,
                     val = true }

local function check_construct(c)
  local by_group = {}
  for _, cl in ipairs(c.classes) do
    local g = CLASSES[cl] and CLASSES[cl].group
    if g then by_group[g] = by_group[g] or {}; table.insert(by_group[g], cl) end
  end
  local has = c.has
  if has.plus then
    for _, cl in ipairs(c.classes) do
      if PLUS_CLASH[cl] then
        return "construct error", string.format(
          "`.plus` cannot go with `.%s`: it signs a number that `.num` or `.pct` prints (rule 1.4.21).", cl)
      end
    end
    for _, k in ipairs({ "if", "n", "sign", "list", "cite" }) do
      if c.keys[k] ~= nil then
        return "construct error", string.format("`.plus` does not apply to a span with `%s=` (rule 1.4.21).", k)
      end
    end
  end
  if c.keys.label ~= nil and not has.p then
    return "construct error", "`label` applies to `.p` only (rule 1.4.17)."
  end
  if has.val then
    for _, cl in ipairs(c.classes) do
      if WORDING_WITH_VAL[cl] then
        return "construct error", string.format("`.val` prints a value as it is and cannot take `.%s` (rule 1.12.2).", cl)
      end
    end
  end
  for _, g in ipairs(GROUP_ORDER) do
    local m = by_group[g]
    if m and #m > 1 then
      local names = {}
      for _, x in ipairs(m) do names[#names + 1] = "." .. x end
      return "construct error", string.format("Two classes from one group in one block: %s (rule 1.4.2).", table.concat(names, " "))
    end
  end
  if (has.pct or has.sci) then
    for _, cl in ipairs({ "no", "word", "count", "ord" }) do
      if has[cl] then
        return "construct error", string.format("`.%s` cannot go with `.%s` (rule 1.4.2).", cl, has.pct and "pct" or "sci")
      end
    end
  end
  -- renderer keys
  for _, key in ipairs({ "digits", "sigfig" }) do
    local v = c.keys[key]
    if v ~= nil and not (has.p and key == "digits") then
      local n = whole_number(v)
      if n == nil or n < 0 then
        return "construct error", string.format("`%s` must be a whole number, not negative (got `%s`).", key, v)
      end
      if n > 100 then
        return "construct error", string.format("`%s` must be at most 100 (got `%s`).", key, v)
      end
      if key == "sigfig" and n < 1 then
        return "construct error", "`sigfig` must be at least 1."
      end
    end
  end
  if c.keys.digits ~= nil and c.keys.sigfig ~= nil then
    return "construct error", "`digits` and `sigfig` together are an error (rule 1.4.7)."
  end
  if has.date and (c.keys.digits ~= nil or c.keys.sigfig ~= nil) then
    return "construct error", "`digits` and `sigfig` do not apply to `.date`."
  end
  if has.p then
    if c.keys.sigfig ~= nil then
      return "construct error", "`sigfig` does not apply to `.p`; use `digits` (rule 1.4.17)."
    end
    local dv = c.keys.digits
    if dv ~= nil then
      local n = tonumber(dv)
      if n == nil or n ~= math.floor(n) or n < 1 or n > 6 or dv:match("[^%d%-%+eE%.]") then
        return "construct error", string.format(
          "`digits` on `.p` must be a whole number from 1 to 6 (got `%s`) (rule 1.4.17).", dv)
      end
    end
  end
  if c.keys.trunc ~= nil then
    local n = whole_number(c.keys.trunc)
    if n == nil or n < 0 then
      return "construct error", string.format("`trunc` must be a whole number, not negative (got `%s`).", c.keys.trunc)
    end
    if n < 1 then return "construct error", "`trunc` must be at least 1 (rule 1.4.7)." end
  end
  if c.keys.none ~= nil then
    if not by_group.collapse then
      return "construct error", "`none` needs a collapse class: .and, .or, .pairs, .ul, .ol or .dl (rule 1.4.14)."
    end
    if has.range then
      return "construct error", "`none` does not apply to `.range`: a range has two ends (rule 1.4.14)."
    end
    if c.keys.none:match("^[ \t\r\n]*$") then
      return "construct error", "`none` must be one string that is not empty or only spaces (rule 1.4.14)."
    end
  end
  for cl in pairs(LIST_CLASS) do
    if has[cl] then
      if has.a or has.cap or has.em or has.strong or c.keys.trunc ~= nil then
        return "construct error", string.format("A text class or `trunc` with `.%s` is an error: a list is a block (rule 1.4.6).", cl)
      end
    end
  end
  return nil
end

-- not implemented is loud (N83): a value error
local UNSHIPPED = { uname = true, usym = true, nounit = true }
local function check_implemented(c)
  for _, cl in ipairs(c.classes) do
    if S.cfg.formatters[cl] then
      return "value error", string.format(
        "`.%s` is a project formatter, which is an R function; a named value cannot use it (rule 2.13.3).", cl)
    end
    if CLASSES[cl] and (not IMPLEMENTED[cl] or UNSHIPPED[cl]) then
      return "value error", string.format(
        "`.%s` on a named value is not available in this version of weft.lua (rule 2.13.3).", cl)
    end
  end
  for _, k in ipairs(c.key_list) do
    if (RENDERER_KEYS[k.k] and not IMPLEMENTED_KEYS[k.k]) or k.k == "unit" then
      return "value error", string.format(
        "`%s=` on a named value is not available in this version of weft.lua (rule 2.13.3).", k.k)
    end
  end
  return nil
end

local function english()
  local l = S.lang
  if not l or l == "" then return true end
  local primary = l:match("^([%a]+)")
  return primary ~= nil and primary:lower() == "en"
end

-- 1.6.5, 1.6.8, E22: what a construct says under a lang weft ships no words for; nil when it is fine
local function lang_problem(c, kind, narms)
  if english() then return nil end
  if (kind == "n" or kind == "list") and narms and narms > 1 then
    return string.format(
      "A `%s` span with more than one arm needs the plural rules of `%s`, which weft does not ship; English rules are never applied to another language (rules 1.6.5, 1.6.7).",
      kind, S.lang)
  end
  local bad
  for _, cl in ipairs(c.classes) do
    for _, e in ipairs(ENGLISH_ONLY) do if e == cl then bad = bad or cl end end
  end
  bad = bad or (c.keys.trunc ~= nil and "trunc" or nil)
  if bad then
    local shown = (bad == "trunc") and "trunc" or ("." .. bad)
    return string.format("The class `%s` prints English words, and the document's `lang` is `%s` (rule 1.6.8).", shown, S.lang)
  end
  return nil
end

local function analyse(el)
  local c = { classes = {}, keys = {}, key_list = {}, pass_classes = {}, pass_attrs = {}, has = {},
              id = el.identifier or "" }
  for _, cl in ipairs(el.classes) do
    c.classes[#c.classes + 1] = cl
    c.has[cl] = true
    if not is_weft_class(cl) then c.pass_classes[#c.pass_classes + 1] = cl end
  end
  for k, v in pairs(el.attributes) do
    if k ~= "weft-at" and k ~= "weft-cap" then
      c.keys[k:lower()] = v
      c.key_list[#c.key_list + 1] = { k = k:lower(), raw = k, v = v }
      if not OWNED_KEYS[k:lower()] then c.pass_attrs[#c.pass_attrs + 1] = { k, v } end
    end
  end
  return c
end

local function wrap_pass(c, inlines)
  if #inlines == 0 then return inlines end
  if #c.pass_classes == 0 and #c.pass_attrs == 0 and c.id == "" then return inlines end
  return pandoc.Inlines({ pandoc.Span(inlines, pandoc.Attr(c.id, c.pass_classes, c.pass_attrs)) })
end

-- a copy of the construct with some classes taken away
local function without(c, drop)
  local has = {}
  for k, v in pairs(c.has) do if not drop[k] then has[k] = v end end
  return { has = has, keys = c.keys, classes = c.classes, id = c.id }
end

-- `target` is nil or "markdown" (today's text) or "tex" (design 9, rule 2.13.16)
local function config_for_num(target)
  local cfg = S.cfg
  return { digits = cfg.digits, decimal_mark = cfg.decimal_mark, big_mark = cfg.big_mark,
           thousands_from = cfg.thousands_from, minus = cfg.minus, p_digits = cfg.p_digits, p_label = cfg.p_label,
           target = target }
end

local function number_keys(c)
  local keys = {}
  if c.keys.digits ~= nil then keys.digits = tonumber(c.keys.digits) end
  if c.keys.sigfig ~= nil then keys.sigfig = tonumber(c.keys.sigfig) end
  if c.has.plus then keys.plus = true end
  return keys
end

-- ---- ids (1.7.5 to 1.7.11) ------------------------------------------------------------------------

-- An id is unique within the document. It is claimed as a failed one, and set when its construct
-- prints; a back-reference to a failed one is a no-value failure.
local function id_claim(c)
  local id = c.id
  if id == "" or S.mute > 0 then return end
  if S.ids[id] then
    cfail(string.format("The id `#%s` is already defined; an id is unique within a document (rule 1.7.5).", id))
  end
  S.ids[id] = { failed = true }
  S.id_log[#S.id_log + 1] = id
end

local function id_set(c, ent)
  if c.id == "" or S.mute > 0 then return end
  S.ids[c.id] = ent
end

-- ---- the formatting pipeline (1.4.1) -----------------------------------------------------------------

local function is_numeric(e) return e.t == "int" or e.t == "float" or e.t == "decimal" end

-- the record as a list of elements, and the names of a named vector (or nil)
local function elements_of(rec)
  if rec._keys then return { rec }, rec._keys end
  if rec.t == "list" then
    local keys = rec.keys
    if type(keys) ~= "table" or keys == pandoc.json.null or #keys ~= #rec.v then keys = nil end
    return rec.v, keys
  end
  return { rec }, nil
end

local function group_int(digits, mark)
  if mark == "" or #digits <= 3 then return digits end
  local parts = {}
  local first = #digits % 3
  if first > 0 then parts[#parts + 1] = digits:sub(1, first) end
  for i = first + 1, #digits, 3 do parts[#parts + 1] = digits:sub(i, i + 2) end
  return table.concat(parts, mark)
end

local function e17(cl, needs, name, kind)
  return string.format("`.%s` needs a %s; `%s` is a %s (rule 1.4.3).", cl, needs, name, cond.kind_name(kind))
end

-- one number element printed as .num or .pct; `warn` asks for the printed-as-zero note (2.6.11)
local function print_elem(e, class, keys, warn, target)
  if S.cfg.pct_proportion == false and class == "pct" then
    vfail("`pct_proportion: false` is not available in this version of weft.lua (rule 2.13.3).")
  end
  local ok, text, info = pcall(num.format, e, class, keys, config_for_num(target))
  if not ok then vfail(tostring(text)) end
  local p = { text = text, number = info.number, decimals = info.decimals, relation = "=", ip = info.ip }
  if warn and info.zero and e.t ~= "int" then
    local v = tonumber(e.v)
    if v ~= nil then
      local sv = class == "pct" and v * 100 or v
      if sv ~= 0 and math.abs(sv - math.floor(sv + 0.5)) >= 1e-9 then
        local shown = string.format("%.12f", sv):gsub("0+$", ""):gsub("%.$", "")
        p.hit = { value = shown, printed = text }
      end
    end
  end
  return p
end

local function zero_message(z)
  return string.format("%s%s printed as %s%s: add sigfig to show it, or digits to confirm it",
                       z.value, z.printed:sub(-1) == "%" and "%" or "", z.printed,
                       z.n > 1 and string.format(" (%d values printed as zero)", z.n) or "")
end

-- Format a record by the classes and keys of a construct, as R's apply_formatters() does (1.4.1).
--   o.governor  stages i and ii only, and the default class when there is none (1.5.7, 1.5.18)
--   o.quiet     no printed-as-zero note
--   o.join      what joins a vector that no collapse class joined
--   o.collapse  the collapse class to use when the construct names none
--   o.bare      numbers with no number class print as the record holds them (1.5.19)
--   o.target    "tex" writes the TeX of design 9 (TX4 to TX6); nil or "markdown" is markdown
-- Returns {text, block, number, decimals, relation, zero}; text is markdown.
local function format_vector(name, rec, c, o)
  o = o or {}
  local cfg, has, keys = S.cfg, c.has, c.keys
  local governor = o.governor
  local elems, nms = elements_of(rec)
  local n = #elems
  local ncl, collapse, wording
  for _, cl in ipairs(NUMBER_STAGE) do if has[cl] then ncl = cl end end
  for _, cl in ipairs(COLLAPSE_STAGE) do if has[cl] then collapse = cl end end
  for _, cl in ipairs(WORDING_STAGE) do if has[cl] then wording = cl end end
  local given = keys.digits ~= nil or keys.sigfig ~= nil
  local default_class = (cfg.governor_class == "pct") and "pct" or "num"
  if governor and not (ncl or has.no or wording or collapse or given) then ncl = default_class end
  if not ncl and has.plus then ncl = "num"
  elseif not ncl and given then ncl = default_class end
  local trunc = keys.trunc ~= nil and math.tointeger(tonumber(keys.trunc)) or nil
  local explicit_collapse = collapse
  if not collapse and not governor then
    collapse = o.collapse or (trunc and "and") or nil
  end

  for i, e in ipairs(elems) do
    if e.t == "missing" then
      nofail(string.format("`%s` has a missing element (element %d) (rule 1.3.4).", name, i))
    elseif e.t == "error" then
      vfail((tostring(e.why or "an element has no value"):gsub("{S}", "`" .. name .. "`")))
    end
  end

  if n == 0 then
    if not governor and keys.none ~= nil and explicit_collapse then
      return { text = text_stage(keys.none, has), relation = "=", decimals = false, none = true }
    end
    nofail(string.format("`%s` is missing (it holds no elements) (rule 1.4.14).", name))
  end

  -- `.val` under TeX (TL4): a number whose text is plain digits as it is, anything else through tex_text()
  if o.target == "tex" and ncl == "val" then
    local parts = {}
    for i, e in ipairs(elems) do parts[i] = scalar_text(e) end
    local text = table.concat(parts, o.join or ", ")
    if not (n == 1 and is_numeric(elems[1]) and (text:match("^%-?%d+$") or text:match("^%-?%d+%.%d+$"))) then
      text = num.tex_text(text)
    end
    return { text = text, relation = "=", decimals = false }
  end

  -- stage i: number
  local range_digits
  if has.range and (ncl == nil or ncl == "num") and not given then
    local all_whole = true
    for _, e in ipairs(elems) do
      if is_numeric(e) and e.t ~= "int" then
        local v = tonumber(e.v)
        if v == v and math.abs(v - math.floor(v + 0.5)) >= 1e-9 then all_whole = false end
      end
    end
    if not all_whole then range_digits = cfg.digits end
  end
  local want_zero = not governor and not o.quiet and not given
  local items, raw = {}, {}
  local data = (keys.none ~= nil or keys.sep ~= nil or keys.last ~= nil)
  for i, e in ipairs(elems) do
    local it
    if ncl == "date" then
      if e.t ~= "date" then vfail(e17("date", "date", name, e.t)) end
      local text, msg = words.date(e.v, cfg.date_format)
      if not text then vfail(msg) end
      it = { text = text, decimals = false, relation = "=" }
    elseif ncl == "sci" or ncl == "p" then
      if not is_numeric(e) then vfail(e17(ncl, "number", name, e.t)) end
      local ok, text, info
      if ncl == "sci" then ok, text, info = pcall(num.format_sci, e, number_keys(c), config_for_num(o.target))
      else
        local pk = { label = keys.label }
        if keys.digits ~= nil then pk.digits = math.tointeger(tonumber(keys.digits)) end
        ok, text, info = pcall(num.format_p, e, config_for_num(o.target), pk)
      end
      if not ok then vfail(tostring(text)) end
      it = { text = text, number = info.number, decimals = info.decimals, relation = info.relation }
    elseif ncl == "val" then
      data = true
      it = { text = scalar_text(e), decimals = false, relation = "=" }
    elseif ncl == "num" or ncl == "pct" or (ncl == nil and is_numeric(e) and not o.bare) then
      if not is_numeric(e) then vfail(e17(ncl, "number", name, e.t)) end
      local keys_n = number_keys(c)
      if range_digits then keys_n.digits = range_digits end
      it = print_elem(e, ncl or "num", keys_n, want_zero, o.target)
    elseif is_numeric(e) then
      it = { text = scalar_text(e), decimals = false, relation = "=" }
    elseif e.t == "bool" then
      it = { text = e.v and "true" or "false", decimals = false, relation = "=" }
    else
      data = true
      it = { text = tostring(e.v), decimals = false, relation = "=" }
    end
    items[i] = it
    raw[i] = is_numeric(e) and tonumber(e.v) or nil
  end
  local hits, first = 0, nil
  for _, it in ipairs(items) do
    if it.hit then hits = hits + 1; first = first or it.hit end
  end

  -- stage ii: wording
  local is_no = {}
  if has.no then
    for i, it in ipairs(items) do
      is_no[i] = it.number ~= nil and it.number == 0 and not it.decimals and it.relation == "="
      if not governor and it.hit then is_no[i] = true end
      if is_no[i] then it.text = "no" end
    end
  end
  if wording then
    for i, it in ipairs(items) do
      if not is_no[i] and (it.number == nil or it.relation ~= "=" or it.decimals or it.number < 0
                           or it.number ~= math.floor(it.number)) then
        vfail(string.format("`.%s` needs a whole number that is not negative, judged as printed (rule 1.4.12); got \"%s\".",
                            wording, it.text))
      end
    end
    for i, it in ipairs(items) do
      if not is_no[i] then
        local nk = it.number
        if wording == "word" then
          if nk < cfg.word_limit then it.text = words.spell_or(nk, it.text) end
        elseif wording == "count" then
          if nk < cfg.count_threshold then it.text = words.spell_or(nk, it.text) end
        elseif it.ip then
          -- the number printer's own text and its whole part as digits: no double decides a digit (2.13.3)
          it.text = it.text .. words.ordinal_suffix(it.ip)
        else
          local digits = string.format("%.0f", nk)
          if nk >= (cfg.thousands_from or 1000) then digits = group_int(digits, cfg.big_mark) end
          it.text = digits .. words.ordinal_suffix((digits:gsub("[^0-9]", "")))
        end
      end
    end
  end

  local P = { relation = "=", decimals = false, data = data }
  if hits > 0 and want_zero then P.zero = { n = hits, value = first.value, printed = first.printed } end
  local texts = {}
  for i, it in ipairs(items) do texts[i] = it.text end

  -- stage iii: collapse (a governor collapses only a range, 1.5.11)
  local text
  if collapse == "range" then
    local number = { items[1] and items[1].number, items[2] and items[2].number }
    local exact_gt
    if n == 2 and is_numeric(elems[1]) and is_numeric(elems[2]) then
      exact_gt = cond.num_cmp(elems[1].v, elems[2].v) > 0
    end
    local t, msg = words.collapse_range(texts, number, raw, cfg.minus, exact_gt, has.plus, o.target)
    if not t then vfail(msg) end
    text = t
    local one_printed = n == 2 and texts[1] == texts[2] and items[1].number == 1 and not items[1].decimals
                        and items[1].relation == "="
    P.number = one_printed and 1 or nil
  elseif governor then
    text = texts[1]
    P.number, P.decimals, P.relation = items[1].number, items[1].decimals, items[1].relation
  elseif collapse then
    local serial = cfg.serial_comma == true and keys.last == nil
    local sep = keys.sep or ", "
    if collapse == "pairs" or collapse == "dl" then
      local ok = nms ~= nil
      if ok then for _, k in ipairs(nms) do if type(k) ~= "string" or k == "" then ok = false end end end
      if not ok then vfail(string.format("`.%s` needs a named vector; this one has no names.", collapse)) end
      if collapse == "pairs" then
        local pairs_t = {}
        for i, t in ipairs(texts) do pairs_t[i] = nms[i] .. " (" .. t .. ")" end
        text = words.collapse_items(pairs_t, sep, keys.last or " and ", trunc, serial)
      else
        text = words.collapse_list("dl", texts, nms)
        P.block = true
      end
    elseif LIST_CLASS[collapse] then
      text = words.collapse_list(collapse, texts, nms)
      P.block = true
    else
      local last = keys.last or (collapse == "or" and " or " or " and ")
      text = words.collapse_items(texts, sep, last, trunc, serial)
    end
  else
    if n > 1 and o.join then text = table.concat(texts, o.join) else text = table.concat(texts, ", ") end
    if n == 1 then P.number, P.decimals, P.relation = items[1].number, items[1].decimals, items[1].relation end
  end

  -- stage iv: text (a `.val` text is data: its text classes are applied to the inlines, after)
  if not governor and not P.block and not has.val then text = text_stage(text, has) end
  if has.val and P.block then P.parts = { texts = texts, nms = nms, cls = collapse } end
  if text:find("\u{2212}", 1, true) then S.minus_used = true end
  P.text = text
  return P
end

-- ---- named values -------------------------------------------------------------------------------------

-- ---- the ledger entries (N112) -------------------------------------------------------------------------

local ARM_ROLES = {
  n = { [1] = { "always" }, [2] = { "one", "other" }, [3] = { "zero", "one", "other" },
        [4] = { "zero", "one", "two", "other" } },
  ["if"] = { [1] = { "always" }, [2] = { "true", "false" } },
  sign = { [2] = { "positive", "negative" }, [3] = { "positive", "negative", "zero" } },
  list = { [2] = { "one", "other" }, [3] = { "zero", "one", "other" }, [4] = { "zero", "one", "two", "other" } },
}

-- the role of arm i of n_arms for a kind, or the arm's number as text (R/ledger.R: ledger_arm)
local function arm_role(kind, n_arms, i)
  local roles = ARM_ROLES[kind] and ARM_ROLES[kind][n_arms]
  if roles and roles[i] then return roles[i] end
  return tostring(i)
end

-- White space made one space. The class is spelled out: %s would take byte 0xA0 of a UTF-8 character
-- for a space in the locale Pandoc sets. A no-break space counts as a space here (Pandoc writes one after
-- "Dr.").
local function squash(text) return (text:gsub("\u{a0}", " "):gsub("[ \t\r\n\f\v]+", " ")) end

-- the number of a single numeric record, for the ledger's `raw`
local function raw_of(rec)
  if type(rec) == "table" and (rec.t == "int" or rec.t == "float" or rec.t == "decimal") then
    local v = tonumber(rec.v)
    if v ~= nil and v == v and v ~= math.huge and v ~= -math.huge then return v end
  end
  return nil
end

local function stringified(r, as_blocks)
  local ok, text = pcall(function()
    if as_blocks then return pandoc.utils.stringify(pandoc.Blocks(r)) end
    return pandoc.utils.stringify(pandoc.Inlines(r))
  end)
  return ok and text or ""
end

-- Runs one construct's resolver in a frame of its own, and records its ledger entry afterwards. The
-- resolver fills S.frame (info, arm, rel, raw) as it learns them. A construct inside an arm is nested:
-- it has an entry too, and takes its outermost construct's sentence.
local function entered(kind, expr, id, inner)
  local frame = { kind = kind, expr = expr, id = id }
  local saved, first, nfail = S.frame, #S.entries + 1, #S.fails
  S.frame = frame
  S.cdepth = S.cdepth + 1
  local r, extra = inner()
  S.cdepth = S.cdepth - 1
  S.frame = saved
  if S.mute > 0 then return r, extra end
  local e = { kind = kind, expr = expr, id = id, context = S.context, section = S.section,
              rel = frame.rel, raw = frame.raw, arm = frame.arm, info = frame.info, top_level = S.cdepth == 0 }
  for i = nfail + 1, #S.fails do
    if frame.info ~= nil and S.fails[i]._info == frame.info then e.failed = S.fails[i].kind; break end
  end
  e.printed = type(r) == "string" and r or stringified(r, extra == true)
  if e.failed then e.arm, e.rel, e.raw = nil, nil, nil end
  for i = first, #S.entries do
    if S.entries[i].top == nil then S.entries[i].top = e end
  end
  S.entries[#S.entries + 1] = e
  return r, extra
end

-- A block of inlines is finished: the sentence of each outermost construct in it (N112), found in the
-- block's text as it now reads, by a search from the end of the previous construct's printed text.
local function finish_block(first, inlines)
  if not S.ledger_on then return end
  local text
  local cursor = 1
  for i = first, #S.entries do
    local e = S.entries[i]
    if e.top == nil and e.sentence == nil then
      text = text or squash(stringified(inlines, false))
      local printed = squash(e.printed or "")
      local s, f
      if printed ~= "" then s, f = text:find(printed, cursor, true) end
      if s then cursor = f + 1 else s, f = cursor, cursor - 1 end
      e.sentence = ledger.sentence(text, s, f)
    end
  end
end

-- the printed record of a governor value under the construct's classes (1.7.8)
local function governor_print(name, rec, c)
  return format_vector(name, rec, c, { governor = true, quiet = true })
end

-- `.ul`, `.ol` and `.dl` of a `.val`: the blocks, built from the texts as they are (they are data, not markdown)
local function val_blocks(parts)
  local function inl(t) return pandoc.Inlines({ pandoc.Str(t) }) end
  local items = {}
  if parts.cls == "dl" then
    for i, t in ipairs(parts.texts) do
      items[i] = { inl(parts.nms[i]), { { pandoc.Para(inl(t)) } } }
    end
    return pandoc.Blocks({ pandoc.DefinitionList(items) })
  end
  for i, t in ipairs(parts.texts) do items[i] = { pandoc.Plain(inl(t)) } end
  if parts.cls == "ol" then
    return pandoc.Blocks({ pandoc.OrderedList(items, pandoc.ListAttributes(1, "Decimal", "Period")) })
  end
  return pandoc.Blocks({ pandoc.BulletList(items) })
end

-- S1: a `claim` or `level` key means a check, and the filter does not read it: a construct error that says
-- how to state the check instead (a guard span around the value, or claim() in code)
local function check_key_error(c, what)
  for _, key in ipairs({ "claim", "level" }) do
    if c.keys[key] ~= nil then
      return string.format(
        "`%s` is not a key the filter reads on %s, so the check would never run. State it with a guard "
        .. "span around the value, [`x`{.num}]{if=\"x < 50\"}, or with claim() in code (rule 5.3.3).", key, what)
    end
  end
  return nil
end

-- N100, N101: `decision` goes on a `.weft-literal` or a `cite` span; elsewhere it is E51
local function decision_wrong(what)
  return string.format(
    "`decision` goes on a `.weft-literal` span or div, a `cite` span or a `claim()`, not on %s (rule 1.8.12).", what)
end
local DECISION_BLANK = "`decision` must not be blank (rule 1.8.12)."
local function decision_blank(el)
  local d = el.attributes and el.attributes["decision"]
  return d ~= nil and not d:match("[^ \t\r\n]")
end
local DECISION_ON = { n = "an `n` span", ["if"] = "an `if` span", sign = "a `sign` span", list = "a `list` span" }

-- Rule 5.2.6 (TX2, E95 to E99): the classes and keys a named value may hold inside math or raw LaTeX, in the
-- scanner's words (R/scan.R: tex_block_errors). `place` is "math" or "raw LaTeX". One message per offending
-- class or key, the classes first, then the keys, in the order written; nil when there is none. A project
-- formatter is the value error of check_implemented(), as outside math.
local TEX_OK_CLASSES = { num = true, pct = true, sci = true, p = true, plus = true, range = true, uname = true,
                         usym = true, nounit = true, val = true }
local TEX_WORDS = { word = true, count = true, ord = true, no = true, date = true, a = true, cap = true }
local TEX_EMPH = { em = true, strong = true }
local TEX_LISTS = { ["and"] = true, ["or"] = true, pairs = true, ul = true, ol = true, dl = true }
local TEX_LIST_KEYS = { sep = true, last = true, trunc = true, none = true }
local TEX_OK_KEYS = { digits = true, sigfig = true, unit = true, label = true, why = true, claim = true,
                      level = true, ["if"] = true, n = true, sign = true, cite = true, list = true }

local function tex_refusals(c, place)
  local out, seen = {}, {}
  local function e99(x)
    return string.format("`%s` cannot be used inside %s: it is not weft's, so weft would put the value in a "
      .. "Pandoc span, and %s has none. Drop it, or move the value out of the %s (rule 5.2.6).", x, place, place, place)
  end
  local function e97(x)
    return string.format("`%s` cannot be used inside %s: it joins items into a phrase or a list. "
      .. "Use `.range` for two ends, or move the value out of the %s (rule 5.2.6).", x, place, place)
  end
  for _, cl in ipairs(c.classes) do
    if not seen[cl] then
      seen[cl] = true
      local x = "." .. cl
      if TEX_OK_CLASSES[cl] or S.cfg.formatters[cl] then
        -- allowed
      elseif TEX_WORDS[cl] then
        out[#out + 1] = string.format("`%s` cannot be used inside %s: it prints words, and a formula holds numbers. "
          .. "Move the value out of the %s, or use a number class such as `.num` (rule 5.2.6).", x, place, place)
      elseif TEX_EMPH[cl] then
        out[#out + 1] = string.format("`%s` cannot be used inside %s: it is markdown emphasis, and %s is TeX. "
          .. "Put \\mathbf{} or \\mathit{} around the value in the formula (rule 5.2.6).", x, place, place)
      elseif TEX_LISTS[cl] then
        out[#out + 1] = e97(x)
      else
        out[#out + 1] = e99(x)
      end
    end
  end
  for _, k in ipairs(c.key_list) do
    if not TEX_OK_KEYS[k.k] then
      out[#out + 1] = TEX_LIST_KEYS[k.k] and e97(k.raw) or e99(k.raw)
    end
  end
  if #out == 0 then return nil end
  return table.concat(out, "\n")
end

local function resolve_code_inner(el, ctx, as_block)
  local shown = shown_code(el)
  local info = info_of(el, ctx, shown)
  S.frame.info = info
  local c = analyse(el)
  if not cond.is_name(el.text) then
    return { fail("construct error", info, string.format(
      "`%s` is not a name, so it cannot carry a weft class: a named value holds one name. Bind the value to a name in code (rule 1.12.3).",
      el.text)) }
  end
  local target = ctx.target
  if target == "tex" then
    local refused = tex_refusals(c, ctx.tex == "math" and "math" or "raw LaTeX")
    if refused then return { fail("construct error", info, refused) } end
  end
  for _, k in ipairs(c.key_list) do
    if GOVERNORS[k.k] then
      return { fail("construct error", info, string.format(
        "A named value takes no `%s`: a governor key belongs on a span (rule 1.3.3).", k.k)) }
    end
  end
  local key_msg = check_key_error(c, "a named value")
  if key_msg then return { fail("construct error", info, key_msg) } end
  if c.keys.decision ~= nil then return { fail("construct error", info, decision_wrong("a named value")) } end
  local kind, detail = check_construct(c)
  if not kind then kind, detail = check_implemented(c) end
  if not kind then detail = lang_problem(c, "value"); if detail then kind = "value error" end end
  if kind then return { fail(kind, info, detail) } end
  local list_class
  for cl in pairs(LIST_CLASS) do if c.has[cl] then list_class = cl end end
  if list_class and not as_block then
    return { fail("construct error", info, string.format(
      "`.%s` makes a block, and must be alone in its paragraph, outside a list item, a block quote and a table cell (rule 1.4.6).",
      list_class)) }
  end

  return guarded(info, function()
    id_claim(c)
    local has = c.has
    local rec = need(el.text)
    local P = format_vector(el.text, rec, c, { join = ", ", target = target })
    if raw_of(rec) ~= nil then
      S.frame.raw = raw_of(rec)
      S.frame.rel = P.relation
    end
    -- an id: the printed record of a single number, for a back-reference (1.7.6)
    if c.id ~= "" and rec.t ~= "list" and is_numeric(rec) and not has.val then
      local ok, G = pcall(governor_print, el.text, rec, c)
      id_set(c, { printed = ok and G or nil, raw = rec })
    elseif c.id ~= "" then
      id_set(c, {})
    end
    local out
    if target == "tex" then
      -- the TeX text goes in as one string, which is not markdown (rule 2.13.16)
      out = pandoc.Inlines({ pandoc.Str(P.text) })
    elseif P.block then
      if P.parts then return val_blocks(P.parts), true end
      return md_blocks(P.text), true
    elseif has.val and not P.none then
      out = pandoc.Inlines({ pandoc.Str(P.text) })
      out = text_inlines(out, has)
    else
      out = md_inlines(P.text, P.data)
    end
    if target ~= "tex" then out = wrap_pass(c, out) end
    if P.zero then warn("printed as zero", info, zero_message(P.zero)) end
    for _, m in ipairs(run_checks(rec, info)) do out:insert(m) end
    return out
  end)
end

local function resolve_code(el, ctx, as_block)
  local id = (el.identifier or "") ~= "" and el.identifier or nil
  return entered("value", el.text, id, function() return resolve_code_inner(el, ctx, as_block) end)
end

-- ---- named values in math and raw LaTeX (design 9, phase 2: D81 to D85, TL1 to TL6) -----------------------

local TEX_MATH_ENVS = {}
for _, n in ipairs({ "equation", "align", "alignat", "gather", "multline", "flalign", "eqnarray", "math",
                     "displaymath", "aligned", "alignedat", "gathered", "split", "cases", "array", "matrix",
                     "pmatrix", "bmatrix", "Bmatrix", "vmatrix", "Vmatrix", "smallmatrix", "subarray", "CD" }) do
  TEX_MATH_ENVS[n] = true
end

-- "math" for a Math element and a raw TeX text that is a math environment; "raw" for any other raw TeX (TL1)
local function tex_kind_of(el)
  if el.t == "Math" then return "math" end
  local name = el.text:match("^%s*\\begin{([%a]+)%*?}")
  if name and TEX_MATH_ENVS[name] then return "math" end
  return "raw"
end

local function is_tex_raw(el)
  return (el.t == "RawInline" or el.t == "RawBlock") and (el.format == "tex" or el.format == "latex")
end

-- the end of an attribute block that opens with `{` at `s`: the position of its `}`, quoted values respected
local function block_end(text, s)
  local i, n, quote = s + 1, #text, nil
  while i <= n do
    local ch = text:sub(i, i)
    if quote then
      if ch == "\\" then i = i + 1
      elseif ch == quote then quote = nil end
    elseif (ch == '"' or ch == "'") and text:sub(i - 1, i - 1) == "=" then
      quote = ch
    elseif ch == "}" then
      return i
    end
    i = i + 1
  end
  return nil
end

-- TL2: the constructs in a TeX text, left to right: {s =, e =, code =} for each backtick run that is not
-- preceded by a backslash and closes on a run of the same length, is followed directly by an attribute block,
-- and reads (as markdown) as exactly one code span that is a weft construct. Nothing is read when there is no
-- backtick.
local function tex_candidates(text)
  local out = {}
  if not text:find("`", 1, true) then return out end
  local pos, n = 1, #text
  while pos <= n do
    local s, e = text:find("`+", pos)
    if not s then break end
    local k = e - s + 1
    local nxt = e + 1
    if not (s > 1 and text:sub(s - 1, s - 1) == "\\") then
      -- the closing run: the next run of exactly k backticks
      local from, cs, ce = e + 1, nil, nil
      while true do
        local a, b = text:find("`+", from)
        if not a then break end
        if b - a + 1 == k then cs, ce = a, b; break end
        from = b + 1
      end
      if cs then
        nxt = ce + 1
        if text:sub(ce + 1, ce + 1) == "{" then
          local be = block_end(text, ce + 1)
          if be then
            local ok, doc = pcall(pandoc.read, text:sub(s, be), "markdown")
            if ok and #doc.blocks == 1 and (doc.blocks[1].t == "Para" or doc.blocks[1].t == "Plain")
               and #doc.blocks[1].content == 1 and doc.blocks[1].content[1].t == "Code"
               and code_candidate(doc.blocks[1].content[1]) then
              out[#out + 1] = { s = s, e = be, code = doc.blocks[1].content[1] }
              nxt = be + 1
            end
          end
        end
      end
    end
    pos = nxt
  end
  return out
end

-- one construct of a TeX text resolved: its TeX as a string (a failure is the marker as text). It goes through
-- resolve_code_inner() with target "tex", so the checks, the value and the ledger are those of prose.
local function tex_marker_text(r)
  local parts = {}
  for _, el in ipairs(r) do
    if el.t == "Span" and el.classes[1] == "weft-marker" then
      parts[#parts + 1] = "\\text{" .. pandoc.utils.stringify(el) .. "}"
    else
      parts[#parts + 1] = pandoc.utils.stringify(el)
    end
  end
  return table.concat(parts)
end

local function resolve_tex_code(el, ctx)
  local id = (el.identifier or "") ~= "" and el.identifier or nil
  return entered("value", el.text, id, function()
    local r = resolve_code_inner(el, ctx, false)
    local text = tex_marker_text(r)
    if ctx.tex == "raw" then text = "\\ensuremath{" .. text .. "}" end
    return text
  end)
end

-- the text with each construct replaced; `ats` is the weft-at attribute of the wrapper ("i:l,i:l" in order)
local function resolve_tex_text(text, kind, ats, ctx)
  local cands = tex_candidates(text)
  if #cands == 0 then return text end
  local places = {}
  if ats then for a in (ats .. ","):gmatch("([^,]*),") do places[#places + 1] = a end end
  local c2 = with(with(ctx, "target", "tex"), "tex", kind)
  local saved = S.context
  if saved == "prose" then S.context = (kind == "math") and "math" or "tex" end
  local pieces, last = {}, 1
  for i, cand in ipairs(cands) do
    local code = cand.code
    if places[i] and places[i] ~= "-" and #cands == #places then code.attributes["weft-at"] = places[i] end
    pieces[#pieces + 1] = text:sub(last, cand.s - 1)
    pieces[#pieces + 1] = resolve_tex_code(code, c2)
    last = cand.e + 1
  end
  S.context = saved
  pieces[#pieces + 1] = text:sub(last)
  return table.concat(pieces)
end

-- the Math, RawInline or RawBlock a `weft-math` wrapper holds, resolved
local function resolve_math_el(el, ats, ctx)
  local copy = el:clone()
  copy.text = resolve_tex_text(el.text, tex_kind_of(el), ats, ctx)
  return copy
end

-- ---- spans ---------------------------------------------------------------------------------------------

-- arms of a span: split at a single `|`; `||` is a literal bar; trimmed (1.5.12)
local function split_arms(inlines)
  local arms, cur = {}, pandoc.Inlines({})
  local function push_text(t) if t ~= "" then cur:insert(pandoc.Str(t)) end end
  for _, el in ipairs(inlines) do
    if el.t == "Str" and el.text:find("|", 1, true) then
      local text, pos = el.text, 1
      local buf = {}
      while pos <= #text do
        local s, e = text:find("|+", pos)
        if not s then buf[#buf + 1] = text:sub(pos); break end
        buf[#buf + 1] = text:sub(pos, s - 1)
        local run = e - s + 1
        buf[#buf + 1] = string.rep("|", run // 2)
        if run % 2 == 1 then
          push_text(table.concat(buf)); buf = {}
          arms[#arms + 1] = cur
          cur = pandoc.Inlines({})
        end
        pos = e + 1
      end
      push_text(table.concat(buf))
    else
      cur:insert(el)
    end
  end
  arms[#arms + 1] = cur
  for _, a in ipairs(arms) do
    while #a > 0 and is_space(a[1]) do a:remove(1) end
    while #a > 0 and is_space(a[#a]) do a:remove(#a) end
  end
  return arms
end

-- the value of a governor key is trimmed of white space at its ends, as R's scanner trims it (the leading
-- kind never reaches here: Pandoc does not read such an attribute as a span, and weft-check.lua fails it)
local function trim_ws(v) return (v:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", "")) end

local function governor_of(el)
  local found, raw
  for k, v in pairs(el.attributes) do
    if GOVERNORS[k:lower()] then
      if found then return found, nil, true end
      found, raw = k:lower(), k
    end
  end
  return found, found and trim_ws(el.attributes[raw]) or nil
end

local function get_key(el, key)
  for k, v in pairs(el.attributes) do if k:lower() == key then return k, v end end
end

local resolve_inlines

-- An arm is its own scope: an id defined inside it does not outlive it (1.7.11).
local function resolve_arm(arm, ctx)
  local mark = #S.id_log
  local out = resolve_inlines(arm, ctx)
  for i = #S.id_log, mark + 1, -1 do
    S.ids[S.id_log[i]] = nil
    S.id_log[i] = nil
  end
  return out
end

-- the chosen arm's text, then the span's own classes (stage iv) and pass-through attributes
local function finish_span(out, c)
  return wrap_pass(c, text_inlines(out, c.has))
end

local function formatter_class_of(c)
  for _, cl in ipairs(c.classes) do
    if CLASSES[cl] and not TEXT_CLASS[cl] then return cl end
  end
  return nil
end

local function resolve_if(el, value, ctx, shown, info, c)
  local nodes, err = cond.parse(value)
  if not nodes then
    local msg = cond.message(err)
    return { fail("construct error", info, msg) }
  end
  if c.has.plus then
    return { fail("construct error", info, "`.plus` does not apply to a span with `if=` (rule 1.4.21).") }
  end
  if formatter_class_of(c) then
    return { fail("construct error", info, "A formatter on an `if` span is an error (rule 1.5.7).") }
  end
  do
    local kind, detail = check_implemented(c)
    if kind then return { fail(kind, info, detail) } end
  end
  local arms = split_arms(el.content)
  if #arms > 2 then
    return { fail("construct error", info, string.format(
      "an `if` span takes one or two arms; this one has %d (rule 1.5.2).", #arms)) }
  end
  local lp = lang_problem(c, "if")
  if lp then return { fail("value error", info, lp) } end
  return guarded(info, function()
    id_claim(c)
    local markers, all = {}, true
    for _, node in ipairs(nodes) do
      local r, reads = cond.evaluate(node, function(name)
        local rec, f = lookup(name)
        if not rec then return nil, f end
        return rec
      end)
      if r == nil then
        raise(reads.kind, reads.detail, reads.hint)
      end
      for _, rec in ipairs(reads) do
        for _, m in ipairs(run_checks(rec, info)) do markers[#markers + 1] = m end
      end
      if not r then
        all = false
        if #arms == 1 then
          local seen, shown_reads = {}, {}
          for _, o in ipairs({ node.a, node.b }) do
            if o and o.name and not seen[o.name] then
              seen[o.name] = true
              local rec = lookup(o.name)
              shown_reads[#shown_reads + 1] = string.format("%s = %s", o.name, rec and val_text(rec) or "?")
            end
          end
          markers[#markers + 1] = fail("failed claim", info,
                                       node.text .. " was false (" .. table.concat(shown_reads, ", ") .. ")",
                                       "optional text is written [phrase | ]{if=\"\u{2026}\"}")
        end
      end
    end
    local arm_i = (#arms == 1 or all) and 1 or 2
    local arm = arms[arm_i]
    S.frame.arm = arm_role("if", #arms, arm_i)
    id_set(c, {})
    local out = resolve_arm(arm, ctx)
    out = finish_span(out, c)
    for _, m in ipairs(markers) do out:insert(m) end
    return out
  end)
end

-- the arm a printed record selects among n_arms arms (1.5.9)
local function pick_arm(n_arms, p)
  if n_arms == 1 then return 1 end
  local exact = p.relation == "=" and not p.decimals and p.number ~= nil
  local zero, one, two = exact and p.number == 0, exact and p.number == 1, exact and p.number == 2
  if n_arms == 2 then return one and 1 or 2 end
  if n_arms == 3 then return zero and 1 or (one and 2 or 3) end
  return zero and 1 or (one and 2 or (two and 3 or 4))
end

local function has_own_format(c)
  local has = c.has
  for _, g in ipairs({ NUMBER_STAGE, WORDING_STAGE, COLLAPSE_STAGE }) do
    for _, cl in ipairs(g) do if has[cl] then return true end end
  end
  return has.no or has.plus or c.keys.digits ~= nil or c.keys.sigfig ~= nil
end

local function id_value_ok(value) return value:match("^#[%w_][%w_.:%-]*$") ~= nil end

-- A back-reference (1.7.6): the printed record of the occurrence, or, when the span has a formatter of
-- its own, the raw value formatted afresh (1.7.8). Returns the printed record and the raw record.
local function backref(value, c, strip)
  local id = value:sub(2)
  local ent = S.ids[id]
  if not ent then
    cfail(string.format("The id `#%s` is not defined before this span, or its arm was not chosen (rule 1.7.10).", id))
  end
  if ent.failed then
    nofail(string.format("The id `#%s` was defined by a value that failed, so it has no value (rule 1.7.10).", id))
  end
  if has_own_format(c) then
    if not ent.raw then vfail(string.format("The id `#%s` has no number to format afresh (rule 1.7.8).", id)) end
    return format_vector(id, strip and ent.raw or ent.raw, c, { governor = true, quiet = true }), ent.raw
  end
  if not ent.printed then vfail(string.format("The id `#%s` has no printed number (rule 1.7.8).", id)) end
  return ent.printed, ent.raw
end

local function single_number(key, name, rec, rule)
  if rec.t == "list" then
    vfail(string.format("`%s` takes a single number, and `%s` is a list; write `length(x)` to count the elements of a vector (rule %s).",
                        key, name, rule))
  end
  if not is_numeric(rec) then
    vfail(string.format("`%s` takes a single number, and `%s` is a %s; write `length(x)` to count the elements of a vector (rule %s).",
                        key, name, kind_name(rec), rule))
  end
end

local function resolve_n(el, value, ctx, shown, info, c)
  local arms = split_arms(el.content)
  if #arms > 4 then
    return { fail("construct error", info, string.format(
      "an `n` span takes one to four arms in English; this one has %d (rule 1.5.2).", #arms)) }
  end
  if value ~= "." and not (cond.is_name(value) or id_value_ok(value)) then
    return { fail("construct error", info, string.format(
      "`%s` is not a name for `n`; it takes a name, `.` or `#id` (rule 1.12.6).", value)) }
  end
  local kind, detail = check_construct(c)
  if not kind then kind, detail = check_implemented(c) end
  if not kind then detail = lang_problem(c, "n", #arms); if detail then kind = "value error" end end
  if kind then return { fail(kind, info, detail) } end
  return guarded(info, function()
    id_claim(c)
    local P, markers = nil, {}
    if value == "." then
      if not ctx.dot then
        cfail("`n=\".\"` is outside an `n` span, so there is no count to agree with (rule 1.7.2).")
      end
      P = ctx.dot
    elseif value:sub(1, 1) == "#" then
      local raw
      P, raw = backref(value, c)
      S.frame.raw = raw_of(raw)
    else
      local rec = need(value)
      if not c.has.range then single_number("n", value, rec, "1.5.11") end
      P = format_vector(value, rec, c, { governor = true, quiet = true })
      S.frame.raw = raw_of(rec)
      markers = run_checks(rec, info)
      id_set(c, { printed = P, raw = (rec.t ~= "list") and rec or nil })
    end
    if value == "." or value:sub(1, 1) == "#" then id_set(c, { printed = P }) end
    local arm_i = pick_arm(#arms, P)
    local arm = arms[arm_i]
    S.frame.arm = arm_role("n", #arms, arm_i)
    S.frame.rel = P.relation
    local out = resolve_arm(arm, with(with(ctx, "hash", P.text), "dot", P))
    out = finish_span(out, c)
    for _, m in ipairs(markers) do out:insert(m) end
    return out
  end)
end

local function abs_record(rec)
  local copy = {}
  for k, v in pairs(rec) do copy[k] = v end
  if type(copy.v) == "string" then copy.v = copy.v:gsub("^%-", "") end
  return copy
end

local function resolve_sign(el, value, ctx, shown, info, c)
  local arms = split_arms(el.content)
  if #arms < 2 or #arms > 3 then
    return { fail("construct error", info, string.format(
      "a `sign` span takes two or three arms; this one has %d (rule 1.5.1).", #arms)) }
  end
  if not (cond.is_name(value) or id_value_ok(value)) then
    return { fail("construct error", info, string.format(
      "`%s` is not a name for `sign`; it takes a name or `#id` (rule 1.12.6).", value)) }
  end
  local kind, detail = check_construct(c)
  if not kind then kind, detail = check_implemented(c) end
  if not kind then detail = lang_problem(c, "sign", #arms); if detail then kind = "value error" end end
  if kind then return { fail(kind, info, detail) } end
  return guarded(info, function()
    id_claim(c)
    -- the sign is judged on the number as printed; wording classes and the magnitude are read from the
    -- absolute value (1.5.10, 1.5.8)
    local judge_c = without(c, { no = true, word = true, count = true, ord = true })
    local judge, mag, rec, markers = nil, nil, nil, {}
    if value:sub(1, 1) == "#" then
      local P, raw = backref(value, judge_c)
      judge = P
      rec = raw
      if has_own_format(c) then
        mag = format_vector(value:sub(2), abs_record(raw), c, { governor = true, quiet = true })
      else
        local txt = P.text
        local minus = S.cfg.minus
        if P.number and P.number < 0 and minus ~= "" and txt:sub(1, #minus) == minus then txt = txt:sub(#minus + 1) end
        mag = { text = txt, number = P.number and math.abs(P.number) or nil, decimals = P.decimals, relation = "=" }
      end
    else
      rec = need(value)
      single_number("sign", value, rec, "1.5.1")
      judge = format_vector(value, rec, judge_c, { governor = true, quiet = true })
      markers = run_checks(rec, info)
    end
    if judge.relation ~= "=" then
      vfail(string.format(
        "A `sign` governor that prints as a bound (\"%s\") has no magnitude to print (rule 1.5.17); write that case with `if`.",
        judge.text))
    end
    if judge.number == nil then vfail("A `sign` governor needs a number, and this has none.") end
    local i = (judge.number > 0) and 1 or ((judge.number < 0) and 2 or 3)
    S.frame.raw = raw_of(rec)
    S.frame.rel = judge.relation
    S.frame.arm = arm_role("sign", #arms, i)
    if i == 3 and #arms == 2 then
      raise("failed claim", string.format(
        "the value printed as \"%s\", which is zero, and a two-arm `sign` has no arm for zero (rule 1.5.3)", judge.text),
        "add a third arm for zero")
    end
    if not mag then
      mag = format_vector(value, abs_record(rec), c, { governor = true, quiet = true })
    end
    id_set(c, { printed = judge, raw = (rec and rec.t ~= "list") and rec or nil })
    local out = resolve_arm(arms[i], with(with(ctx, "hash", mag.text), "dot", mag))
    out = finish_span(out, c)
    for _, m in ipairs(markers) do out:insert(m) end
    return out
  end)
end

-- true when an arm holds a `#` that is the placeholder (an odd run), outside the spans it holds
local function arm_has_hash(arm)
  for _, el in ipairs(arm) do
    if el.t == "Str" then
      for run in el.text:gmatch("#+") do if #run % 2 == 1 then return true end end
    end
  end
  return false
end

local function resolve_list(el, value, ctx, shown, info, c)
  local arms = split_arms(el.content)
  if #arms < 2 or #arms > 4 then
    return { fail("construct error", info, string.format(
      "a `list` span takes two to four arms in English; this one has %d (rule 1.5.19).", #arms)) }
  end
  if not cond.is_name(value) then
    return { fail("construct error", info, string.format(
      "`%s` is not a name for `list`; it takes a name (rule 1.12.6).", value)) }
  end
  if c.id ~= "" then
    return { fail("construct error", info, "A `list` span takes no `#id` (rule 1.7.5).") }
  end
  for cl in pairs(LIST_CLASS) do
    if c.has[cl] then
      return { fail("construct error", info, string.format(
        "A list class (`.%s`) on a `list` span is an error: `#` is inline (rule 1.5.19).", cl)) }
    end
  end
  if #arms >= 3 and arm_has_hash(arms[1]) then
    return { fail("construct error", info, "`#` in the zero arm of a `list` span is an error: there is nothing to print (rule 1.5.19).") }
  end
  local kind, detail = check_construct(c)
  if not kind then kind, detail = check_implemented(c) end
  if not kind then detail = lang_problem(c, "list", #arms); if detail then kind = "value error" end end
  if kind then return { fail(kind, info, detail) } end
  return guarded(info, function()
    local rec = need(value)
    local elems = elements_of(rec)
    for i, e in ipairs(elems) do
      if e.t == "missing" then
        nofail(string.format("A `list` governor has a missing element (`%s`, element %d) (rule 1.5.19).", value, i))
      end
    end
    local len = #elems
    if len == 0 and #arms == 2 then
      raise("failed claim", "the list is empty, and a two-arm `list` span has no arm for the empty case (rule 1.5.3); add a first arm for the empty case")
    end
    local hash, zero = "", nil
    if len > 0 then
      local cl = without(c, { a = true, cap = true, em = true, strong = true })
      local P = format_vector(value, rec, cl, { collapse = "and", bare = not has_own_format(c) })
      hash = P.text
      zero = P.zero
    end
    local count = { text = tostring(len), number = len, decimals = false, relation = "=" }
    local arm_i = pick_arm(#arms, count)
    S.frame.arm = arm_role("list", #arms, arm_i)
    local out = resolve_arm(arms[arm_i], with(with(with(ctx, "hash", hash), "dot", count), "hash_data", true))
    out = finish_span(out, c)
    if zero then warn("printed as zero", info, zero_message(zero)) end
    for _, m in ipairs(run_checks(rec, info)) do out:insert(m) end
    return out
  end)
end

local CITE_KEY = "^[%w_][%w_:%.#%$%%&%-%+%?<>~/]*$"

local function resolve_cite(el, value, ctx, shown, info, c)
  if c.id ~= "" then
    return { fail("construct error", info, "A `cite` span takes no `#id` (rule 1.7.5).") }
  end
  if c.has.plus then
    return { fail("construct error", info, "`.plus` does not apply to a span with `cite=` (rule 1.4.21).") }
  end
  local formatter = formatter_class_of(c)
  if formatter then
    return { fail("construct error", info, string.format(
      "A formatter class (`.%s`) on a `cite` span is an error (rule 1.8.7).", formatter)) }
  end
  local with_at = value:find("@", 1, true) ~= nil
  if not with_at then
    local ok = value:match("[^ \t\r\n]") ~= nil
    for part in (value .. ";"):gmatch("(.-);") do
      local key = part:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", "")
      if not key:match(CITE_KEY) then ok = false end
    end
    if not ok then
      return { fail("construct error", info, string.format(
        "`cite=\"%s\"` has no `@`, so it must be citation keys separated by `;` (rule 1.8.4).", value)) }
    end
  end
  local lp = lang_problem(c, "cite")
  if lp then return { fail("value error", info, lp) } end
  return guarded(info, function()
    local out = finish_span(resolve_inlines(el.content, ctx), c)
    if with_at then
      out:insert(pandoc.Space())
      out:extend(pandoc.utils.blocks_to_inlines(pandoc.read("[" .. value .. "]", "markdown").blocks))
    end
    return out
  end)
end

-- a bracket with a text class and no governor (1.1.9)
local function is_text_span(el)
  if el.classes:includes("weft-literal") then return false end
  for k in pairs(el.attributes) do
    if GOVERNORS[k:lower()] then return false end
  end
  for _, cl in ipairs(el.classes) do
    if TEXT_CLASS[cl] then return true end
  end
  return false
end

local function resolve_text_span(el, ctx)
  local c = analyse(el)
  local text = pandoc.utils.stringify(el.content):gsub("[ \t\r\n]+", " ")
  local classes = {}
  for _, cl in ipairs(el.classes) do classes[#classes + 1] = "." .. cl end
  local info = info_of(el, ctx, string.format("[%s]{%s}", cut(text, 60), table.concat(classes, " ")))
  if c.id ~= "" then
    return { fail("construct error", info, "A text span takes no `#id` (rule 1.1.9).") }
  end
  if c.keys.decision ~= nil then return { fail("construct error", info, decision_wrong("a text span")) } end
  local kind, detail = check_construct(c)
  if not kind then detail = lang_problem(c, "text"); if detail then kind = "value error" end end
  if kind then return { fail(kind, info, detail) } end
  return guarded(info, function()
    return finish_span(resolve_inlines(el.content, ctx), c)
  end)
end

local function resolve_span_inner(el, ctx)
  local key, value, many = governor_of(el)
  if not key then return nil end
  local rawkey = get_key(el, key)
  local shown = shown_span(el, rawkey, value)
  local info = info_of(el, ctx, shown)
  S.frame.info = info
  local c = analyse(el)
  if many then
    return { fail("construct error", info, "A span takes one governor key (rule 1.5.1).") }
  end
  local key_msg = check_key_error(c, "a span")
  if key_msg then return { fail("construct error", info, key_msg) } end
  if c.keys.decision ~= nil then
    if key ~= "cite" then return { fail("construct error", info, decision_wrong(DECISION_ON[key])) } end
    if decision_blank(el) then return { fail("construct error", info, DECISION_BLANK) } end
  end
  if key == "if" then return resolve_if(el, value, ctx, shown, info, c) end
  if key == "n" then return resolve_n(el, value, ctx, shown, info, c) end
  if key == "sign" then return resolve_sign(el, value, ctx, shown, info, c) end
  if key == "list" then return resolve_list(el, value, ctx, shown, info, c) end
  return resolve_cite(el, value, ctx, shown, info, c)
end

-- Does a governor fit N9 and N12: the grammar the filter resolves in a document the knitr hooks resolve?
local function governor_fits(key, value, many)
  if many or value == nil then return false end
  if key == "if" then return cond.parse(value) ~= nil end
  if key == "n" then return value == "." or cond.is_name(value) or id_value_ok(value) end
  if key == "sign" then return cond.is_name(value) or id_value_ok(value) end
  if key == "list" then return cond.is_name(value) end
  return true
end

local function resolve_span(el, ctx)
  local key, value, many = governor_of(el)
  if not key then return nil end
  -- N92: in a knitr document a span whose governor does not fit is left for weft-check.lua; what it
  -- holds is still resolved
  if S.knitr and not governor_fits(key, value, many) then
    el.attributes["weft-at"] = nil
    el.content = resolve_inlines(el.content, ctx)
    return { el }
  end
  local expr = key
  if value then
    expr = squash(value):gsub("^ ", ""):gsub(" $", "")
    if key == "cite" then
      expr = expr .. " | " .. squash(pandoc.utils.stringify(el.content)):gsub("^ ", ""):gsub(" $", "")
    end
  end
  local id = (key ~= "cite" and (el.identifier or "") ~= "") and el.identifier or nil
  return entered(key, expr, id, function() return resolve_span_inner(el, ctx) end)
end

-- ---- inlines and blocks -------------------------------------------------------------------------------

local INLINE_CONTAINERS = {
  Emph = true, Strong = true, Strikeout = true, Superscript = true, Subscript = true, SmallCaps = true,
  Underline = true, Quoted = true, Link = true, Cite = true, Span = true,
}

local function closes_after(nxt)
  if nxt == nil then return true end
  if nxt.t ~= "Str" then return false end
  local t = nxt.text
  local c = t:sub(1, 1)
  if c ~= "" and (".,;:!?)]"):find(c, 1, true) then return true end
  local three = t:sub(1, 3)
  return three == "\u{201D}" or three == "\u{2019}" or three == "\u{2014}"
end

local resolve_blocks

-- a Str with the `#` placeholders replaced by the governor's printed text (1.5.8, 1.5.12): a pair of
-- `#` is a literal one; the text is markdown, so a superscript in it stays one
local function hash_inlines(text, hash, data)
  local out = pandoc.Inlines({})
  local buf = {}
  local function flush()
    if #buf > 0 then out:insert(pandoc.Str(table.concat(buf))); buf = {} end
  end
  local pos = 1
  while pos <= #text do
    local s, e = text:find("#+", pos)
    if not s then buf[#buf + 1] = text:sub(pos); break end
    buf[#buf + 1] = text:sub(pos, s - 1)
    local run = e - s + 1
    buf[#buf + 1] = string.rep("#", run // 2)
    if run % 2 == 1 then
      local got = md_inlines(hash, data)
      if #got == 1 and got[1].t == "Str" then
        buf[#buf + 1] = got[1].text
      else
        flush()
        out:extend(got)
      end
    end
    pos = e + 1
  end
  flush()
  return out
end

resolve_inlines = function(inlines, ctx)
  local out = pandoc.Inlines({})
  local i, n = 1, #inlines
  while i <= n do
    local el = inlines[i]
    local t = el.t
    if t == "Code" then
      if code_candidate(el) then out:extend(resolve_code(el, ctx)) else out:insert(el) end
      i = i + 1
    elseif t == "Span" and el.classes[1] == "weft-math" then
      local inner = el.content[1]
      if inner ~= nil and (inner.t == "Math" or is_tex_raw(inner)) then
        out:insert(resolve_math_el(inner, el.attributes["weft-at"], ctx))
      else
        out:extend(el.content)
      end
      i = i + 1
    elseif t == "Span" and is_text_span(el) then
      out:extend(resolve_text_span(el, ctx))
      i = i + 1
    elseif t == "Span" and governor_of(el) then
      -- a chain of governed spans with nothing between them (1.5.20)
      local j, results, printed = i, {}, false
      while j <= n and inlines[j].t == "Span" and governor_of(inlines[j]) do
        local r = resolve_span(inlines[j], ctx)
        results[#results + 1] = r
        if #r > 0 then printed = true end
        j = j + 1
      end
      if printed then
        for _, r in ipairs(results) do out:extend(r) end
        i = j
      else
        local prev, nxt = out[#out], inlines[j]
        if is_space(prev) and is_space(nxt) then
          out:remove(#out)
          i = j
        elseif prev == nil and is_space(nxt) then
          i = j + 1
        elseif is_space(prev) and closes_after(nxt) then
          out:remove(#out)
          i = j
        else
          i = j
        end
      end
    elseif t == "Str" then
      if ctx.hash and el.text:find("#", 1, true) then out:extend(hash_inlines(el.text, ctx.hash, ctx.hash_data)) else out:insert(el) end
      i = i + 1
    elseif t == "Note" then
      el.content = resolve_blocks(el.content, ctx)
      out:insert(el)
      i = i + 1
    elseif t == "Image" then
      S.stash[#S.stash + 1] = { content = el.caption, ctx = ctx, section = S.section }
      el.attributes["weft-cap"] = tostring(#S.stash)
      el.caption = pandoc.Inlines({})
      out:insert(el)
      i = i + 1
    elseif t == "Span" and el.classes:includes("weft-literal") and decision_blank(el) then
      local text = pandoc.utils.stringify(el.content):gsub("[ \t\r\n]+", " ")
      local info = info_of(el, ctx, string.format("[%s]{.weft-literal}", cut(text, 60)))
      out:insert(fail("construct error", info, DECISION_BLANK))
      i = i + 1
    elseif INLINE_CONTAINERS[t] then
      if t == "Span" and el.classes:includes("weft-literal") then
        el.attributes["why"] = nil
        el.attributes["decision"] = nil
      end
      el.content = resolve_inlines(el.content, ctx)
      out:insert(el)
      i = i + 1
    else
      out:insert(el)
      i = i + 1
    end
  end
  return out
end

local function cell_label(el)
  local id = el.identifier or ""
  if id == "" then return nil end
  return (id:gsub("^cell%-", ""))
end

-- A paragraph that is one named value with a list class (.ul .ol .dl) makes a block (1.4.6).
local function list_class_code(el)
  if #el.content ~= 1 then return nil end
  local code = el.content[1]
  if code.t ~= "Code" or not code_candidate(code) then return nil end
  for _, cl in ipairs(code.classes) do
    if cl == "ul" or cl == "ol" or cl == "dl" then return code end
  end
  return nil
end

-- N57 (the julia engine): a failed @claim prints its carrier as text, because Quarto drops the displayed
-- block of a cell that raises. Such a block arrives as a CodeBlock inside a `cell-output-stdout` div whose text
-- ENDS with one fenced `weft-values` block (a backtick or tilde fence); whatever the cell printed before it
-- stays as output. The fence is turned into a real carrier block, which is then read and removed like any
-- other. A fence that something follows, and any other code block, is left alone. Returns the bodies of the
-- carriers found at the end (in the order printed) and the text left before them, or nil.
local function printed_carrier(el)
  local text = el.text:gsub("[ \t\r\n]+$", "")
  local lines = {}
  for l in (text .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = l end
  local bodies = {}
  while #lines >= 3 do
    local closer = lines[#lines]:match("^([`~]+)[ \t\r\n]*$")
    if not closer or #closer < 3 then break end
    local ch = closer:sub(1, 1)
    local open_at
    for i = #lines - 1, 1, -1 do
      local l = lines[i]
      local fence = l:match("^(" .. (ch == "`" and "`" or "~") .. "+)[ \t\r\n]*{%.weft%-values}[ \t\r\n]*$")
      if fence then
        if #fence >= 3 and #closer >= #fence then open_at = i end
        break
      end
      if l:match("^[ \t\r\n]*%" .. ch .. "%" .. ch .. "%" .. ch .. "+[ \t\r\n]*$") then break end
    end
    if not open_at then break end
    table.insert(bodies, 1, table.concat(lines, "\n", open_at + 1, #lines - 1))
    for i = #lines, open_at, -1 do lines[i] = nil end
    while #lines > 0 and lines[#lines]:match("^[ \t\r\n]*$") do lines[#lines] = nil end
  end
  if #bodies == 0 then return nil end
  return bodies, table.concat(lines, "\n")
end

-- inside a list item, a block quote or a table cell a list class is an error: resolved as inline
local function mark_nested(el, ctx)
  local function fix(p)
    local code = list_class_code(p)
    if code then
      local r = pandoc.Inlines(resolve_code(code, ctx, false))
      return (p.t == "Plain") and pandoc.Plain(r) or pandoc.Para(r)
    end
  end
  return el:walk({ Para = fix, Plain = fix })
end

resolve_blocks = function(blocks, ctx)
  local function block_para(el)
    local code = list_class_code(el)
    if not code then return nil end
    local out, is_blocks = resolve_code(code, ctx, true)
    if is_blocks then return out, false end
    out = pandoc.Inlines(out)
    return ((el.t == "Plain") and pandoc.Plain(out) or pandoc.Para(out)), false
  end
  return blocks:walk({
    traverse = "topdown",
    Para = block_para,
    Plain = block_para,
    BlockQuote = function(el) return mark_nested(el, ctx) end,
    BulletList = function(el) return mark_nested(el, ctx) end,
    OrderedList = function(el) return mark_nested(el, ctx) end,
    DefinitionList = function(el) return mark_nested(el, ctx) end,
    Div = function(el)
      if el.classes[1] == "weft-math" then
        local inner = el.content[1]
        if inner ~= nil and is_tex_raw(inner) then
          local first = #S.entries + 1
          local out = resolve_math_el(inner, el.attributes["weft-at"], ctx)
          finish_block(first, pandoc.Inlines({ pandoc.Str(out.text) }))
          return out, false
        end
        return el.content, false
      end
      if el.classes:includes("weft-literal") then
        if decision_blank(el) then
          local info = info_of(el, ctx, "::: {.weft-literal}")
          return pandoc.Para({ fail("construct error", info, DECISION_BLANK) })
        end
        el.attributes["why"] = nil
        el.attributes["decision"] = nil
      end
      if el.classes:includes("cell-output-stdout") then
        local content, changed = pandoc.Blocks({}), false
        for _, b in ipairs(el.content) do
          local bodies, before
          if b.t == "CodeBlock" and not b.classes:includes("weft-values") then bodies, before = printed_carrier(b) end
          if bodies then
            changed = true
            if before ~= "" then content:insert(pandoc.CodeBlock(before, b.attr)) end
            for _, body in ipairs(bodies) do
              content:insert(pandoc.CodeBlock(body, pandoc.Attr("", { "weft-values" })))
            end
          else
            content:insert(b)
          end
        end
        if changed then el.content = content end
      end
      if el.classes:includes("cell") then
        el.content = resolve_blocks(el.content, with(ctx, "cell", cell_label(el)))
        return el, false
      end
      return el
    end,
    CodeBlock = function(el)
      if el.classes:includes("weft-values") then
        read_block(el, ctx)
        return {}
      end
    end,
    Table = function(el)
      S.stash[#S.stash + 1] = { caption = el.caption, ctx = ctx, section = S.section }
      el.attr.attributes["weft-cap"] = tostring(#S.stash)
      el.caption = pandoc.Caption({}, nil)
      return mark_nested(el, ctx)
    end,
    Figure = function(el)
      S.stash[#S.stash + 1] = { caption = el.caption, ctx = ctx, section = S.section }
      local attr = el.attr
      attr.attributes["weft-cap"] = tostring(#S.stash)
      -- the content of a Figure cannot be set in place: a new Figure
      return pandoc.Figure(resolve_blocks(el.content, with(ctx, "fig", true)),
                           pandoc.Caption({}, nil), attr), false
    end,
    Header = function(el)
      S.section = el.identifier or ""
      return nil
    end,
    Inlines = function(inlines)
      local first = #S.entries + 1
      local out = resolve_inlines(inlines, ctx)
      finish_block(first, out)
      return out, false
    end,
  })
end

local function restore_captions(blocks)
  local function take(attrs)
    local k = attrs["weft-cap"]
    if not k then return nil end
    attrs["weft-cap"] = nil
    return S.stash[tonumber(k)]
  end
  local function caption(st)
    S.section = st.section or ""
    local long = resolve_blocks(st.caption.long, st.ctx)
    local short = nil
    if st.caption.short then
      S.mute = S.mute + 1
      short = resolve_inlines(st.caption.short, st.ctx)
      S.mute = S.mute - 1
    end
    return pandoc.Caption(long, short)
  end
  return blocks:walk({
    Table = function(el)
      local st = take(el.attr.attributes)
      if st then el.caption = caption(st); return el end
    end,
    Figure = function(el)
      local st = take(el.attr.attributes)
      if st then el.caption = caption(st); return el end
    end,
    Image = function(el)
      local st = take(el.attributes)
      if st then
        if st.ctx.fig then S.mute = S.mute + 1 end
        S.section = st.section or ""
        local first = #S.entries + 1
        el.caption = resolve_inlines(st.content, st.ctx)
        finish_block(first, el.caption)
        if st.ctx.fig then S.mute = S.mute - 1 end
        return el
      end
    end,
  })
end

-- ---- forward references (N90 to N94): what the document publishes, wherever it stands ------------------

-- a text for a record that ignores its `checks`, so that two records compare as N91 says (a float's `v` is
-- text in the carrier, so it compares as text)
local function canon(v, top)
  if v == pandoc.json.null then return "null" end
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t == "number" then return string.format("%.17g", v) end
  if t ~= "table" then return tostring(v) end
  local parts = {}
  if is_array(v) then
    for i, x in ipairs(v) do parts[i] = canon(x, false) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for k in pairs(v) do
    if not (top and k == "checks") then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for i, k in ipairs(keys) do parts[i] = string.format("%q", tostring(k)) .. ":" .. canon(v[k], false) end
  return "{" .. table.concat(parts, ",") .. "}"
end

-- Before the main pass: every block the main pass will read (a `weft-values` block or file, and a printed
-- carrier of a cell output, N57), in document order, in S.fwd[name] = { last = record, n = distinct values }.
-- A block that does not read is left to the main pass to report.
local function prepass(doc)
  S.fwd = {}
  local function take(el)
    local d, _, names = parse_block(el)
    if not d then return end
    for _, k in ipairs(names) do
      local rec = d.values[k]
      local f = S.fwd[k]
      if not f then f = { seen = {}, n = 0 }; S.fwd[k] = f end
      local key = canon(rec, true)
      if not f.seen[key] then f.seen[key] = true; f.n = f.n + 1 end
      f.last = rec
    end
  end
  doc:walk({
    traverse = "topdown",
    Div = function(el)
      if el.classes:includes("cell-output-stdout") then
        for _, b in ipairs(el.content) do
          if b.t == "CodeBlock" and not b.classes:includes("weft-values") then
            local bodies = printed_carrier(b)
            if bodies then
              for _, body in ipairs(bodies) do take(pandoc.CodeBlock(body, pandoc.Attr("", { "weft-values" }))) end
            end
          end
        end
      end
    end,
    CodeBlock = function(el)
      if el.classes:includes("weft-values") then take(el) end
    end,
  })
end

-- ---- lines (N89): tag each construct, before anything is resolved --------------------------------------

local function prev_not_backtick(text, s)
  return s == 1 or text:sub(s - 1, s - 1) ~= "`"
end

-- D82: a Math, a raw TeX inline or a raw TeX block that holds constructs is wrapped, in a Span (a Div for a
-- block) with class `weft-math` and `weft-at="i:l,i:l"`, one entry for each construct in document order ("-"
-- where the source has none). The wrapper is taken off when the text is resolved. With no backtick in the
-- text, nothing is read and the element is left as it is.
local function tag_tex(el)
  if el.t ~= "Math" and not is_tex_raw(el) then return nil end
  local cands = tex_candidates(el.text)
  if #cands == 0 then return nil end
  local ats = {}
  for i, cand in ipairs(cands) do
    local idx, line
    if S.src ~= nil then
      -- the occurrence that reads as this very construct first; failing that, the next one of the name
      local needle = "`" .. cand.code.text .. "`{"
      local tail = el.text:sub(cand.s, cand.e):match("`+(%{.*)$") or "{"
      idx, line = S.src:find(needle, function(text, st)
        local from = st + #needle - 1
        return prev_not_backtick(text, st) and text:sub(from, from + #tail - 1) == tail
      end)
      if not idx then idx, line = S.src:find(needle, prev_not_backtick) end
    end
    ats[i] = idx and (idx .. ":" .. line) or "-"
  end
  local attr = pandoc.Attr("", { "weft-math" }, { ["weft-at"] = table.concat(ats, ",") })
  if el.t == "RawBlock" then return pandoc.Div({ el }, attr), false end
  return pandoc.Span({ el }, attr), false
end

local function tag(el)
  if el.t == "Math" or el.t == "RawInline" then return tag_tex(el) end
  if S.src == nil then return nil end
  local needle, ok
  if el.t == "Code" then
    if not code_candidate(el) then return nil end
    needle, ok = "`" .. el.text .. "`{", prev_not_backtick
  elseif el.t == "Span" then
    local key, value = governor_of(el)
    if not key and el.classes:includes("weft-literal") then
      -- only a blank decision is an error that needs a line
      if not decision_blank(el) then return nil end
      needle = string.format('decision="%s"', el.attributes["decision"])
    elseif not key then
      -- a text span has no key to search for: its first text class
      if not is_text_span(el) then return nil end
      for _, cl in ipairs(el.classes) do
        if TEXT_CLASS[cl] then needle = "." .. cl; break end
      end
    else
      local rawkey, rawvalue = get_key(el, key)
      needle = string.format('%s="%s"', rawkey, rawvalue)
    end
  else
    return nil
  end
  local idx, line = S.src:find(needle, ok)
  if idx then
    el.attributes["weft-at"] = idx .. ":" .. line
    return el
  end
  return nil
end

local META_FIELDS = { "title", "subtitle", "abstract", "description" }

local function tag_all(doc)
  local f = { traverse = "topdown", Inline = tag, RawBlock = tag_tex,
    Div = function(el)
      if S.src == nil or not el.classes:includes("weft-literal") or not decision_blank(el) then return nil end
      local idx, line = S.src:find(string.format('decision="%s"', el.attributes["decision"]))
      if idx then el.attributes["weft-at"] = idx .. ":" .. line; return el end
    end }
  for _, key in ipairs(META_FIELDS) do
    local v = doc.meta[key]
    local ty = v ~= nil and pandoc.utils.type(v) or nil
    if ty == "Inlines" then
      doc.meta[key] = pandoc.Pandoc({ pandoc.Plain(v) }):walk(f).blocks[1].content
    elseif ty == "Blocks" then
      doc.meta[key] = pandoc.Pandoc(v):walk(f).blocks
    end
  end
  doc.blocks = doc.blocks:walk(f)
  return doc
end

-- ---- the run -------------------------------------------------------------------------------------------

-- N89, N110, N112: rmarkdown hands Pandoc `doc.knit.md`; the source, its lines, its stamp and its ledger are the
-- `.Rmd` (or `.Rmarkdown`) beside it, when there is one
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

-- ---- table digests (design 8, G2; GT1 to GT9) -----------------------------------------------------------
-- The tables a jupyter or julia cell shows: one entry of kind `table` each, whose text is the xxh3 digest of
-- the cells' text, tab and LF joined (the same digest on every Pandoc, whether the table came as Markdown,
-- as raw HTML or as a Table that Quarto made). The caption is not in it.

local function squash_trim(text)
  return ((squash(text):gsub("^ +", ""):gsub(" +$", "")))
end

-- the canonical text of a Table (GT3): head rows, then each body's head and body rows, then the foot rows
local function table_canon(tbl)
  local rows = {}
  local function add_rows(list)
    for _, row in ipairs(list or {}) do
      local cells = {}
      for _, c in ipairs(row.cells) do
        cells[#cells + 1] = squash_trim(pandoc.utils.stringify(pandoc.Pandoc(c.contents)))
      end
      rows[#rows + 1] = cells
    end
  end
  add_rows(tbl.head and tbl.head.rows)
  for _, b in ipairs(tbl.bodies or {}) do
    add_rows(b.head)
    add_rows(b.body)
  end
  add_rows(tbl.foot and tbl.foot.rows)
  local any, lines = false, {}
  for _, cells in ipairs(rows) do
    for _, c in ipairs(cells) do if c ~= "" then any = true end end
    lines[#lines + 1] = table.concat(cells, "\t")
  end
  if not any then return nil end
  return table.concat(lines, "\n")
end

-- the outer Tables of a raw HTML block (GT2): none when the text holds no `<table` or does not read
local function html_tables(text)
  local out = {}
  if not text:lower():find("<table", 1, true) then return out end
  local ok, doc = pcall(pandoc.read, text, "html")
  if not ok or doc == nil then return out end
  pcall(function()
    doc.blocks:walk({
      traverse = "topdown",
      Table = function(el) out[#out + 1] = el; return nil, false end,
    })
  end)
  return out
end

local function cut80(text)
  if utf8.len(text) == nil or utf8.len(text) <= 80 then return text end
  return text:sub(1, utf8.offset(text, 81) - 1) .. "..."
end

-- Quarto turns a labelled `tbl-` cell into a FloatRefTarget before this filter runs: the cell loses its id,
-- which now belongs to the float (the id and the caption are read from it); the float's own caption is
-- the last scaffold child
local function float_of(cell)
  for _, b in ipairs(cell.content) do
    if b.t == "Div" and b.attributes and b.attributes["__quarto_custom_type"] == "FloatRefTarget" then return b end
  end
  return nil
end

local function float_label(div)
  local q = type(quarto) == "table" and quarto or nil
  local rq = _quarto or (q and q._quarto)
  if type(rq) ~= "table" or type(rq.ast) ~= "table" or type(rq.ast.resolve_custom_data) ~= "function" then return nil end
  local ok, d = pcall(rq.ast.resolve_custom_data, div)
  if ok and type(d) == "table" then
    local id = d.identifier
    if type(id) == "string" and id ~= "" then return (id:gsub("^cell%-", "")) end
  end
  return nil
end

local function float_caption(div)
  local last = div.content[#div.content]
  if last and last.t == "Div" and last.attributes and last.attributes["__quarto_custom_scaffold"] then
    local parts = {}
    for _, b in ipairs(last.content) do
      if b.t == "Plain" or b.t == "Para" then parts[#parts + 1] = pandoc.utils.stringify(b) end
    end
    return squash_trim(table.concat(parts, " "))
  end
  return ""
end

local function record_tables(blocks)
  local section = ""
  local function add(tbl, cell)
    local canon = table_canon(tbl)
    if not canon then return end
    local sentence = squash_trim(pandoc.utils.stringify(tbl.caption.long))
    if sentence == "" then sentence = squash_trim(cell.cap_attr or "") end
    if sentence == "" then sentence = cell.float_cap or "" end
    if sentence == "" then sentence = cut80((canon:gsub("[\t\n]", " "))) end
    local label = cell.label
    S.entries[#S.entries + 1] = {
      kind = "table", expr = label or "", id = label, context = "chunk", section = section,
      printed = ledger.xxh3(canon), sentence = sentence,
    }
  end
  local scan
  local function html_raw(b)
    return b.t == "RawBlock" and (b.format == "html" or b.format == "html4" or b.format == "html5")
  end
  local function count(text, pat)
    local n, from = 0, 1
    local low = text:lower()
    while true do
      local a, z = low:find(pat, from, true)
      if not a then return n end
      n, from = n + 1, z + 1
    end
  end
  local function scan_list(list, cell)
    local i, n = 1, #list
    while i <= n do
      local b = list[i]
      -- Markdown read with raw HTML splits a bare HTML table into one RawBlock per tag and a Plain per
      -- cell: the run of siblings from `<table` to its `</table>` is written back as HTML and read as one
      local last = i
      if cell and html_raw(b) then
        local depth = count(b.text, "<table") - count(b.text, "</table")
        local j = i
        while depth > 0 and j < n do
          j = j + 1
          local c = list[j]
          if html_raw(c) then depth = depth + count(c.text, "<table") - count(c.text, "</table") end
        end
        if j > i and depth <= 0 then
          local run = {}
          for k = i, j do run[#run + 1] = list[k] end
          local ok, text = pcall(pandoc.write, pandoc.Pandoc(run), "html")
          if ok and type(text) == "string" then
            for _, tbl in ipairs(html_tables(text)) do add(tbl, cell) end
            last = j
          end
        end
      end
      if last == i then scan(b, cell) end
      i = last + 1
    end
  end
  scan = function(b, cell)
    local t = b.t
    if t == "Header" then
      section = b.identifier or ""
    elseif t == "Div" then
      if b.classes:includes("cell") then
        local fl = float_of(b)
        local label = cell_label(b)
        if not label and fl then label = float_label(fl) end
        cell = { label = label, cap_attr = b.attributes["tbl-cap"], float_cap = fl and float_caption(fl) or nil }
      end
      scan_list(b.content, cell)
    elseif t == "Figure" or t == "BlockQuote" then
      scan_list(b.content, cell)
    elseif t == "BulletList" or t == "OrderedList" then
      for _, item in ipairs(b.content) do scan_list(item, cell) end
    elseif t == "DefinitionList" then
      for _, item in ipairs(b.content) do
        for _, def in ipairs(item[2]) do scan_list(def, cell) end
      end
    elseif cell then
      if t == "Table" then
        add(b, cell)
      elseif t == "RawBlock" and (b.format == "html" or b.format == "html4" or b.format == "html5") then
        for _, tbl in ipairs(html_tables(b.text)) do add(tbl, cell) end
      end
    end
  end
  scan_list(blocks, nil)
end

local function remove_empty_cells(blocks)
  return blocks:walk({
    Div = function(el)
      if #el.content == 0 then
        for _, c in ipairs(el.classes) do
          if c == "cell" or c == "cell-output" or c:find("^cell%-output%-") then return {} end
        end
      end
    end,
  })
end

-- ---- paths, the stamp and the ledger (N110 to N113) ----------------------------------------------------

local function normpath(p)
  p = p:gsub("\\", "/")
  local lead = p:sub(1, 1) == "/" and "/" or ""
  local out = {}
  for seg in p:gmatch("[^/]+") do
    if seg == "." then
      -- nothing
    elseif seg == ".." and #out > 0 and out[#out] ~= ".." then
      out[#out] = nil
    else
      out[#out + 1] = seg
    end
  end
  return lead .. table.concat(out, "/")
end

local function abs_path(p)
  if p:sub(1, 1) == "/" or p:match("^%a:[/\\]") then return normpath(p) end
  if S.cwd then return normpath(S.cwd .. "/" .. p) end
  return nil
end

local function dir_of(p) return (p:gsub("/[^/]*$", "")) end
local function base_of(p) return (p:match("([^/\\]*)$")) end

-- a path relative to the project's root, as R's state_source() gives it
local function root_rel(abs)
  if S.root and abs then
    local pre = S.root:gsub("/+$", "") .. "/"
    if abs:sub(1, #pre) == pre then return abs:sub(#pre + 1) end
  end
  return abs and base_of(abs) or nil
end

-- N30: the text of a values file. A path is relative to the document's folder, or to the project root when it
-- starts with `/`; the root is the folder holding _weft.yml, else _quarto.yml, else the document's folder. The
-- path is normalised (`.` and `..` collapsed, no symlinks followed: pure Lua cannot) and must stay inside the
-- root, else it is refused. A file read is kept for the ledger's header (N112).
values_file_text = function(path)
  if path == "" then return nil, "the path is empty" end
  if path:find("%z") then return nil, "the path is not a path" end
  if path:match("^%a:") or path:sub(1, 2) == "\\\\" or path:sub(1, 2) == "//" then
    return nil, "the path is outside the project"
  end
  local root = S.root
  if not root and S.main_dir then
    local q = config.find_upward(S.main_dir, "_quarto.yml")
    root = q and normpath(dir_of(normpath(q))) or S.main_dir
  end
  if not root then return nil, "the project's folder is not known" end
  root = normpath(root)
  local joined
  local p = path:gsub("\\", "/")
  if p:sub(1, 1) == "/" then
    joined = root .. p
  elseif S.main_dir then
    joined = S.main_dir .. "/" .. p
  else
    return nil, "the document's folder is not known"
  end
  local abs = normpath(joined)
  local pre = root:gsub("/+$", "") .. "/"
  if abs:sub(1, #pre) ~= pre then return nil, "the path is outside the project" end
  local f, err = io.open(abs, "rb")
  if not f then
    return nil, (err and err:find("No such file", 1, true)) and "no such file" or (err and err:gsub("^.-: ", "") or "cannot open")
  end
  -- the size first (review 6, #20c): a file over the limit is not read into memory
  local size = f:seek("end")
  if size and size > 5000000 then
    f:close()
    return nil, string.format("%d bytes, and the limit is 5000000", size)
  end
  f:seek("set", 0)
  local text, rerr = f:read("a")
  f:close()
  if not text then return nil, (rerr and rerr:gsub("^.-: ", "") or "cannot read") end
  S.values_files = S.values_files or {}
  S.values_files[#S.values_files + 1] = abs
  return text
end

-- the output's name: WEFT_OUTPUT, else Pandoc's output file, else the source's name, with no folder or extension
local function output_name()
  local function strip(x) return (base_of(x):gsub("%.[^.]*$", "")) end
  local e = os.getenv("WEFT_OUTPUT")
  if e and e ~= "" then return strip(e) end
  local of = PANDOC_STATE and PANDOC_STATE.output_file
  if of and of ~= "" and of ~= "-" then return strip(of) end
  return strip(S.src_rel or "document")
end

local function oldest_text(at)
  return os.date("%Y-%m-%d %H:%M:%S", at)
end

local function warn_write(what, why)
  io.stderr:write(string.format("weft: %s could not be written: %s\n", what, tostring(why)))
end

-- the stamp (N110): merged with the hooks' of this run, or new
local function write_stamp(run)
  local dir = S.root .. "/.weft/stamps"
  local ok_dir = ledger.make_dirs(dir)
  if not ok_dir then return warn_write("the stamp for " .. S.src_rel, "no folder") end
  local gi = S.root .. "/.weft/.gitignore"
  local f = io.open(gi, "r")
  if f then f:close() else ledger.write_file(gi, "*\n") end
  local path = dir .. "/" .. stamp.file_name(S.src_rel)
  local old = stamp.read(path)
  local checks, named = 0, 0
  for _, e in ipairs(S.entries) do
    if e.top_level then checks = checks + 1 end
    if not e.failed and e.kind ~= "table" then named = named + 1 end
  end
  local merge = false
  if old and old.run == run then
    merge = true
    if type(old.writers) == "table" then
      for _, w in ipairs(old.writers) do if w == "filter" then merge = false end end
    end
  end
  -- a knitr document whose hooks wrote no stamp in this run, and nothing of the filter's own to record:
  -- it was served from freeze. Its old stamp, or the lack of one, is what the post-render notice reads
  -- (N121); a stamp of this run would hide both.
  if S.knitr and not merge and S.nblocks == 0 and #S.entries == 0 and #S.fails == 0 then return end
  local failures, writers = {}, { "knit" }
  local s = { source = S.src_rel, run = run, named = named }
  -- review 6, #10: a knitr document whose stamp is of another run was served from freeze: what the knit
  -- recorded then (its failures, its checks, when it executed) is kept, and this pass adds its own
  local carried = S.knitr and not merge and old ~= nil and old.run ~= run
  if carried then
    s.executed = type(old.executed) == "string" and old.executed or oldest_text(os.time())
    local had_filter = false
    writers = {}
    if type(old.writers) == "table" then
      for _, w in ipairs(old.writers) do
        writers[#writers + 1] = w
        if w == "filter" then had_filter = true end
      end
    end
    if #writers == 0 then writers = { "knit" } end
    if type(old.failures) == "table" then
      for _, x in ipairs(old.failures) do
        -- the filter's own findings of the earlier pass are made again now; the knit's are kept
        if type(x) == "table" and x.source ~= "resolve" and x.source ~= "filter" then
          failures[#failures + 1] = stamp.failure_line(x)
        end
      end
    end
    s.checks = (tonumber(old.checks) or 0) + (had_filter and 0 or checks)
    if not had_filter then writers[#writers + 1] = "filter" end
  elseif merge then
    s.executed = type(old.executed) == "string" and old.executed or oldest_text(os.time())
    s.checks = (tonumber(old.checks) or 0) + checks
    if type(old.failures) == "table" then
      for _, x in ipairs(old.failures) do
        if type(x) == "table" then failures[#failures + 1] = stamp.failure_line(x) end
      end
    end
    if type(old.writers) == "table" and #old.writers > 0 then writers = old.writers end
    local w = {}
    for _, x in ipairs(writers) do w[#w + 1] = x end
    writers = w
    writers[#writers + 1] = "filter"
  else
    s.executed = oldest_text(S.oldest_at or os.time())
    s.checks = checks
    writers = { "filter" }
  end
  for _, x in ipairs(S.fails) do failures[#failures + 1] = report.json_line(x) end
  s.failures = failures
  s.writers = writers
  if run ~= "" and S.nblocks > 0 then s.fresh = not S.any_stale end
  local ok, err = stamp.write(path, s)
  if not ok then warn_write("the stamp for " .. S.src_rel, err) end
end

-- the ledger (N112): the filter's entries merged into the file the hooks may have written
local function write_ledger()
  local files, seen = {}, {}
  local function add(abs)
    local rel = root_rel(abs)
    if rel and not seen[rel] then seen[rel] = true; files[#files + 1] = { rel = rel, abs = abs } end
  end
  add(S.src_abs)
  if S.src then for _, f in ipairs(S.src.files) do add(abs_path(f)) end end
  for _, f in ipairs(S.values_files or {}) do add(f) end
  local list = {}
  for _, e in ipairs(S.entries) do
    local abs = S.src_abs
    if e.info and e.info.idx and S.src and S.src.files[e.info.idx] then abs = abs_path(S.src.files[e.info.idx]) or abs end
    local t = e
    while t.top do t = t.top end
    list[#list + 1] = {
      file = root_rel(abs) or S.src_rel, section = e.section, kind = e.kind, expr = e.expr, id = e.id,
      context = e.context, text = (not e.failed) and e.printed or nil, arm = e.arm, rel = e.rel, raw = e.raw,
      failed = e.failed, sentence = t.sentence or "",
    }
  end
  local dir = S.root .. "/_weft/ledger/" .. S.src_rel
  local ok_dir = ledger.make_dirs(dir)
  if not ok_dir then return warn_write("the ledger for " .. S.src_rel, "no folder") end
  local out = output_name()
  local ok, err = ledger.write({ path = dir .. "/" .. out .. ".jsonl", source = S.src_rel, output = out,
                                 files = files, entries = list })
  if not ok then warn_write("the ledger for " .. S.src_rel, err) end
end

local MINUS_DECL = "\\usepackage{iftex}\\ifPDFTeX\\DeclareUnicodeCharacter{2212}{\\ensuremath{-}}\\fi"

local function add_minus_declaration(meta)
  local existing = meta["header-includes"]
  local list
  if existing == nil then list = pandoc.MetaList({})
  elseif pandoc.utils.type(existing) == "List" then list = existing
  else list = pandoc.MetaList({ existing }) end
  for _, item in ipairs(list) do
    if pandoc.utils.stringify(item):find("DeclareUnicodeCharacter{2212}", 1, true) then return end
  end
  list[#list + 1] = pandoc.MetaBlocks({ pandoc.RawBlock("latex", MINUS_DECL) })
  meta["header-includes"] = list
end

function Pandoc(doc)
  local ok_cwd, cwd = pcall(pandoc.system.get_working_directory)
  if not ok_cwd then cwd = nil end
  local path = source_path()
  S.cwd = cwd
  S.main = path and shown_path(path) or nil
  if path then
    local d = path:gsub("[/\\]+[^/\\]*$", "")
    if d == path then d = "." end
    if cwd and d:sub(1, 1) ~= "/" then d = (cwd .. "/" .. d):gsub("/%./", "/"):gsub("/%.$", "") end
    S.main_dir = d
  elseif cwd then
    S.main_dir = cwd
  end
  local text = path and read_file(path) or nil
  local cfg, problems = config.load(path, text, cwd)
  S.cfg = cfg
  if S.main_dir then S.main_dir = normpath(S.main_dir) end
  -- the project (a set-up one has _weft.yml), the source in it, and the current run (N91, N110)
  S.current_run = current_run() or false
  if S.main_dir and path then
    S.src_abs = S.main_dir .. "/" .. base_of(path)
    local yml = config.find_upward(S.main_dir, "_weft.yml")
    if yml then
      S.root = normpath(dir_of(normpath(yml)))
      S.src_rel = root_rel(S.src_abs)
    end
  end
  S.ledger_on = S.root ~= nil and cfg.ledger ~= false
  -- N92: a document the knitr hooks resolve, by its source, or by the hooks' stamp of this run
  S.knitr = config.source_is_knitr(path, text)
  if not S.knitr and S.root and S.src_rel and S.current_run then
    local old = stamp.read(S.root .. "/.weft/stamps/" .. stamp.file_name(S.src_rel))
    if old and old.run == S.current_run then
      local filtered = false
      if type(old.writers) == "table" then
        for _, w in ipairs(old.writers) do if w == "filter" then filtered = true end end
      end
      S.knitr = not filtered
    end
  end
  local lang = doc.meta.lang
  S.lang = lang ~= nil and pandoc.utils.stringify(lang) or nil
  S.src = path and lines_lib.new(path) or nil
  for _, p in ipairs(problems) do
    record(S.fails, "construct error", { shown = p.key .. ": " .. p.value, idx = nil, chunk = nil },
           string.format("%s: `%s: %s` is not a %s; the default is used (rule 9.1.6).", p.file, p.key, p.value, p.what))
    S.fails[#S.fails].file = p.file
  end

  doc = tag_all(doc)
  prepass(doc)
  local ctx = {}
  local blocks = resolve_blocks(doc.blocks, ctx)
  blocks = restore_captions(blocks)
  if S.ledger_on and not S.knitr then record_tables(blocks) end
  local meta = doc.meta
  S.section, S.context = "", "front-matter"
  for _, key in ipairs(META_FIELDS) do
    local v = meta[key]
    local ty = v ~= nil and pandoc.utils.type(v) or nil
    if ty == "Inlines" then
      local first = #S.entries + 1
      meta[key] = resolve_inlines(v, ctx)
      finish_block(first, meta[key])
    elseif ty == "Blocks" then meta[key] = resolve_blocks(v, ctx) end
  end
  S.context = "prose"
  -- weft-check.lua reads this, and takes it away: the document is one this filter resolves (review 6, #2)
  meta["weft-resolved"] = pandoc.MetaBool(true)
  blocks = remove_empty_cells(blocks)
  if S.minus_used and (FORMAT == "latex" or FORMAT == "beamer") then add_minus_declaration(meta) end

  -- the report (N86)
  local draft = truthy_env("WEFT_DRAFT") or cfg.draft == true
  if S.stale then
    io.stderr:write(string.format(
      "weft: the values in %s were published by run %s, not this run (%s): served from freeze or a cache, or by a kernel kept from an earlier render. Their checks did not run now (rule 2.13.8).\n",
      S.main or "this document", S.stale.run, S.stale.current))
  end
  local coll
  if #S.fails > 0 or #S.warned > 0 then
    coll = report.collect_path(dir_up_find, quarto ~= nil)
    -- Open finding 11: under Quarto, with the collection file open, the post-render script prints the one report
    -- of the render (it reads this filter's lines from that file), so the filter does not print it too. Plain
    -- Pandoc, and a Quarto render with no post-render script (so no open file), print it here.
    if not (quarto ~= nil and coll) then io.stderr:write(report.build(S.fails, S.warned)) end
  end
  -- the stamp always, the ledger when the render does not stop on its failures (N110, N112; D8, D20)
  if S.root and S.src_rel then
    local ok, err = pcall(write_stamp, S.current_run or "")
    if not ok then warn_write("the stamp for " .. S.src_rel, err) end
    if S.ledger_on and (#S.fails == 0 or draft or coll) then
      ok, err = pcall(write_ledger)
      if not ok then warn_write("the ledger for " .. S.src_rel, err) end
    end
  end
  if #S.fails > 0 or #S.warned > 0 then
    if coll then
      local f = io.open(coll, "a")
      if f then
        for _, x in ipairs(S.fails) do f:write(report.json_line(x), "\n") end
        for _, x in ipairs(S.warned) do f:write(report.json_line(x, "warn"), "\n") end
        f:close()
      else
        io.stderr:write("weft: cannot append to " .. coll .. "\n")
        if not draft and #S.fails > 0 then os.exit(1) end
      end
    elseif #S.fails > 0 and not draft then
      os.exit(1)
    end
  end
  return pandoc.Pandoc(blocks, meta)
end

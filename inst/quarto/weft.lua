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

-- ---- what weft owns -----------------------------------------------------------------------------

-- every class weft owns, with its at-most-one group; `val` is the filter's own
local CLASSES = {}
for _, c in ipairs({ "num", "pct", "sci", "p", "date", "val" }) do CLASSES[c] = { group = "number" } end
for _, c in ipairs({ "word", "count", "ord" }) do CLASSES[c] = { group = "wording" } end
CLASSES["no"] = { group = "no" }
for _, c in ipairs({ "and", "or", "pairs", "range", "ul", "ol", "dl" }) do CLASSES[c] = { group = "collapse" } end
for _, c in ipairs({ "uname", "usym", "nounit" }) do CLASSES[c] = { group = "unit" } end
CLASSES["a"] = { group = "a" }
CLASSES["cap"] = { group = "cap" }
CLASSES["strong"] = { group = "emphasis" }
CLASSES["em"] = { group = "emphasis" }

-- the governor keys, and the keys weft owns on a construct
local GOVERNORS = { ["if"] = true, n = true, sign = true, list = true, cite = true }
local RENDERER_KEYS = { digits = true, sigfig = true, sep = true, last = true, trunc = true, none = true }
local OWNED_KEYS = { unit = true, level = true, ["weft-at"] = true, ["weft-cap"] = true }
for k in pairs(GOVERNORS) do OWNED_KEYS[k] = true end
for k in pairs(RENDERER_KEYS) do OWNED_KEYS[k] = true end

local GROUP_ORDER = { "number", "wording", "collapse", "unit", "emphasis" }
local WORDING_WITH_VAL = { no = true, word = true, count = true, ord = true }

-- the classes this filter implements (6c): the printers for a named value
local IMPLEMENTED = { num = true, pct = true, val = true }
local IMPLEMENTED_KEYS = { digits = true, sigfig = true }

-- ---- state --------------------------------------------------------------------------------------

local S = {
  values = {}, valid = {}, fails = {}, warned = {}, cfg = nil, src = nil, main = nil,
  stash = {}, mute = 0, minus_used = false, stale = nil, lang = nil,
}

local function with(ctx, k, v)
  local c = {}
  for a, b in pairs(ctx) do c[a] = b end
  c[k] = v
  return c
end

local function is_space(el) return el ~= nil and (el.t == "Space" or el.t == "SoftBreak") end

-- ---- locations and failures -----------------------------------------------------------------------

local function file_of(idx)
  if S.src and idx and S.src.files[idx] then
    local f = S.src.files[idx]
    return (f:gsub("^%./", ""))
  end
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
    expr = info.shown, detail = detail, hint = hint,
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

local function valid_date(v)
  if type(v) ~= "string" then return false end
  local y, m, d = v:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then return false end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if m < 1 or m > 12 or d < 1 then return false end
  local dim = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 then dim[2] = 29 end
  return d <= dim[m]
end

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

local function record_problem(r)
  if type(r) ~= "table" then return "it is not an object" end
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
  else
    r = raw
  end
  S.valid[name] = r
  return r
end

local function kind_name(r) return cond.kind_name(r.t) end

local function scalar_text(r)
  if r.t == "bool" then return r.v and "true" or "false" end
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
  if S.values[name] == nil then
    return nil, {
      kind = "no value",
      detail = string.format("no value is published under the name `%s` above this point (rule 1.12.6).", name),
      hint = string.format(
        "Publish it in code above: weft_put(%s = ...) in R, put(%s=...) in Python, @put %s in Julia. "
        .. "A cell with include: false or output: false publishes nothing on the jupyter and julia engines.",
        name, name, name),
    }
  end
  local r = record_of(name)
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
    for _ = 1, 8 do
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

local function current_run()
  local e = os.getenv("WEFT_RUN")
  if e and e ~= "" then return e end
  local f = dir_up_find(".weft/run")
  if f then
    local l = f:read("l")
    f:close()
    if l and l ~= "" then return l end
  end
  return nil
end

local function block_failure(el, ctx, detail)
  local info = { shown = nil, chunk = ctx.cell }
  info.shown = "a weft-values block"
  record(S.fails, "construct error", info, detail)
end

local function read_block(el, ctx)
  local text = el.text
  if el.attributes["file"] then
    block_failure(el, ctx, "a weft-values block with `file=` is not available in this version of weft.lua (rule 2.13.10).")
    return
  end
  if #text > 5000000 then
    block_failure(el, ctx, string.format("a weft-values block of %d bytes; the limit is 5000000 (rule 2.13.1).", #text))
    return
  end
  local ok, d = pcall(pandoc.json.decode, text, false)
  local function bad(reason)
    block_failure(el, ctx, string.format("a weft-values block that does not read: %s (rule 2.13.1).", reason))
  end
  if not ok or d == nil or d == pandoc.json.null then return bad("not JSON") end
  if type(d) ~= "table" or getmetatable(d) ~= nil then return bad("not a JSON object") end
  if type(d.weft) ~= "number" or d.weft ~= 1 then return bad("`weft` is not 1") end
  if type(d.values) ~= "table" or getmetatable(d.values) ~= nil then return bad("no `values` object") end
  local names = {}
  for k in pairs(d.values) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do
    if not cond.is_name(k) then return bad(string.format("`%s` in `values` is not a name", k)) end
  end
  for _, k in ipairs(names) do
    S.values[k] = d.values[k]
    S.valid[k] = nil
  end
  -- freshness (N91)
  local now = S.current_run
  if now == nil then S.current_run = current_run() or false; now = S.current_run end
  if now and S.stale == nil then
    local run = d.run
    if run ~= now then S.stale = { run = (type(run) == "string") and run or "null", current = now } end
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
  local text = pandoc.utils.stringify(el.content):gsub("%s+", " ")
  text = text:gsub("^ ", ""):gsub(" $", "")
  return string.format('[%s]{%s="%s"}', cut(text, 60), key, value)
end

-- ---- named values (N5 to N8, N17, N82, N83) ---------------------------------------------------------

local function is_weft_class(c) return CLASSES[c] ~= nil or S.cfg.formatters[c] == true end

local function code_candidate(el)
  local has_class, has_key = false, false
  for _, c in ipairs(el.classes) do if is_weft_class(c) then has_class = true end end
  for k in pairs(el.attributes) do
    if RENDERER_KEYS[k:lower()] then has_key = true end
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

-- the construct's own classes and keys; returns a failure (kind, detail) or nil
local function check_construct(c, is_span)
  -- groups
  local by_group = {}
  for _, cl in ipairs(c.classes) do
    local g = CLASSES[cl] and CLASSES[cl].group
    if g then by_group[g] = by_group[g] or {}; table.insert(by_group[g], cl) end
  end
  local has = {}
  for _, cl in ipairs(c.classes) do has[cl] = true end
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
    if v ~= nil then
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
  if c.keys.none ~= nil and not by_group.collapse then
    return "construct error", "`none` needs a collapse class: .and, .or, .pairs, .ul, .ol or .dl (rule 1.4.14)."
  end
  return nil
end

-- not implemented is loud (N83): a value error
local function check_implemented(c, only_governor_classes)
  for _, cl in ipairs(c.classes) do
    if S.cfg.formatters[cl] then
      return "value error", string.format(
        "`.%s` is a project formatter, which is an R function; a named value cannot use it (rule 2.13.3).", cl)
    end
    if CLASSES[cl] and not IMPLEMENTED[cl] then
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

local function analyse(el)
  local c = { classes = {}, keys = {}, key_list = {}, pass_classes = {}, pass_attrs = {},
              id = el.identifier or "" }
  for _, cl in ipairs(el.classes) do
    c.classes[#c.classes + 1] = cl
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

local function config_for_num()
  local cfg = S.cfg
  return { digits = cfg.digits, decimal_mark = cfg.decimal_mark, big_mark = cfg.big_mark,
           thousands_from = cfg.thousands_from, minus = cfg.minus }
end

local function number_keys(c)
  local keys = {}
  if c.keys.digits ~= nil then keys.digits = tonumber(c.keys.digits) end
  if c.keys.sigfig ~= nil then keys.sigfig = tonumber(c.keys.sigfig) end
  return keys
end

local function number_value(r)
  return tonumber(r.v)
end

-- the number a record prints for a class, and the warned check of 2.6.11: returns text, info, zero_note
local function print_number(r, class, c, quiet_zero)
  if S.cfg.pct_proportion == false and class == "pct" then
    error({ detail = "`pct_proportion: false` is not available in this version of weft.lua (rule 2.13.3)." }, 0)
  end
  local keys = number_keys(c)
  local ok, text, info = pcall(num.format, r, class, keys, config_for_num())
  if not ok then error({ detail = tostring(text) }, 0) end
  if text:find("\u{2212}", 1, true) then S.minus_used = true end
  local zero_note = nil
  if not quiet_zero and keys.digits == nil and keys.sigfig == nil and info.zero and r.t ~= "int" then
    local v = number_value(r)
    if v ~= nil then
      local sv = class == "pct" and v * 100 or v
      if sv ~= 0 and math.abs(sv - math.floor(sv + 0.5)) >= 1e-9 then
        local shown = string.format("%.12f", sv):gsub("0+$", ""):gsub("%.$", "")
        zero_note = string.format("%s%s printed as %s: add sigfig to show it, or digits to confirm it",
                                  shown, class == "pct" and "%" or "", text)
      end
    end
  end
  return text, info, zero_note
end

local function resolve_code(el, ctx)
  local shown = shown_code(el)
  local info = info_of(el, ctx, shown)
  local c = analyse(el)
  if not cond.is_name(el.text) then
    return { fail("construct error", info, string.format(
      "`%s` is not a name, so it cannot carry a weft class: a named value holds one name. Bind the value to a name in code (rule 1.12.3).",
      el.text)) }
  end
  for _, k in ipairs(c.key_list) do
    if GOVERNORS[k.k] then
      return { fail("construct error", info, string.format(
        "A named value takes no `%s`: a governor key belongs on a span (rule 1.3.3).", k.k)) }
    end
  end
  local kind, detail = check_construct(c)
  if not kind then kind, detail = check_implemented(c) end
  if kind then return { fail(kind, info, detail) } end

  local rec, failure = lookup(el.text)
  if not rec then return { fail(failure.kind, info, failure.detail, failure.hint) } end

  local class = nil
  for _, cl in ipairs(c.classes) do if cl == "num" or cl == "pct" or cl == "val" then class = cl end end
  local out = pandoc.Inlines({})
  if class == "val" or class == nil then
    -- a named value with a renderer key only prints as a number, as .num does (1.5.18)
    if class == nil then class = S.cfg.governor_class == "pct" and "pct" or "num" end
  end
  local zero_note
  if class == "val" then
    local text, why = val_text(rec)
    if not text then return { fail("no value", info, string.format("`%s` is missing (%s) (rule 1.3.4).", el.text, why)) } end
    out:insert(pandoc.Str(text))
  else
    if rec.t ~= "int" and rec.t ~= "float" and rec.t ~= "decimal" then
      return { fail("value error", info, string.format("`.%s` needs a number; `%s` is a %s (rule 1.4.3).",
                                                       class, el.text, kind_name(rec))) }
    end
    local ok, text, _, zn = pcall(print_number, rec, class, c, false)
    if not ok then
      local d = type(text) == "table" and text.detail or tostring(text)
      return { fail("value error", info, d) }
    end
    zero_note = zn
    out:insert(pandoc.Str(text))
  end
  out = wrap_pass(c, out)
  if zero_note then warn("printed as zero", info, zero_note) end
  for _, m in ipairs(run_checks(rec, info)) do out:insert(m) end
  return out
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

local function governor_of(el)
  local found
  for k, v in pairs(el.attributes) do
    if GOVERNORS[k:lower()] then
      if found then return found, nil, true end
      found = k:lower()
    end
  end
  return found, found and el.attributes[found] or nil
end

local function get_key(el, key)
  for k, v in pairs(el.attributes) do if k:lower() == key then return k, v end end
end

local resolve_inlines

local function resolve_arm(arm, ctx)
  return resolve_inlines(arm, ctx)
end

local function english()
  local l = S.lang
  if not l or l == "" then return true end
  local primary = l:match("^([%a]+)")
  return primary ~= nil and primary:lower() == "en"
end

local function resolve_if(el, value, ctx, shown, info, c)
  local nodes, err = cond.parse(value)
  if not nodes then
    local msg
    if err.id == "E4" then
      msg = string.format("`%s` compares two literals and has no name, so it is always the same (rule 1.12.4).", err.part)
    else
      msg = string.format("`%s` is not a name or one comparison of names, numbers and 'strings'; bind the condition to a name in code (rule 1.12.4).", err.part)
    end
    return { fail("construct error", info, msg) }
  end
  for _, cl in ipairs(c.classes) do
    if IMPLEMENTED[cl] or CLASSES[cl] and CLASSES[cl].group == "number" then
      return { fail("construct error", info, "A formatter on an `if` span is an error (rule 1.5.7).") }
    end
  end
  local arms = split_arms(el.content)
  if #arms > 2 then
    return { fail("construct error", info, string.format(
      "an `if` span takes one or two arms; this one has %d (rule 1.5.2).", #arms)) }
  end
  local markers, all = {}, true
  for _, node in ipairs(nodes) do
    local r, reads = cond.evaluate(node, function(name)
      local rec, f = lookup(name)
      if not rec then return nil, f end
      return rec
    end)
    if r == nil then
      return { fail(reads.kind, info, reads.detail, reads.hint) }
    end
    for _, rec in ipairs(reads) do
      for _, m in ipairs(run_checks(rec, info)) do markers[#markers + 1] = m end
    end
    if not r then
      all = false
      if #arms == 1 then
        markers[#markers + 1] = fail("failed claim", info, node.text .. " was false",
                                     "optional text is written [phrase | ]{if=\"\u{2026}\"}")
      end
    end
  end
  local arm = (#arms == 1 or all) and arms[1] or arms[2]
  local out = resolve_arm(arm, ctx)
  out = wrap_pass(c, out)
  for _, m in ipairs(markers) do out:insert(m) end
  return out
end

local function pick_arm(n_arms, info)
  if n_arms == 1 then return 1 end
  local one = info.one and not info.decimals
  if n_arms == 2 then return one and 1 or 2 end
  if n_arms == 3 then return info.zero and 1 or (one and 2 or 3) end
  return info.zero and 1 or (one and 2 or (info.two and 3 or 4))
end

local function resolve_n(el, value, ctx, shown, info, c)
  local arms = split_arms(el.content)
  if #arms > 4 then
    return { fail("construct error", info, string.format(
      "an `n` span takes one to four arms in English; this one has %d (rule 1.5.2).", #arms)) }
  end
  local printed, pinfo, markers
  markers = {}
  if value == "." then
    if not ctx.ginfo then
      return { fail("construct error", info, "`n=\".\"` is outside an `n` span, so there is no count to agree with (rule 1.7.2).") }
    end
    printed, pinfo = ctx.hash, ctx.ginfo
  elseif value:sub(1, 1) == "#" then
    return { fail("value error", info, "`n=#id` on a named value is not available in this version of weft.lua (rule 2.13.3).") }
  else
    if not cond.is_name(value) then
      return { fail("construct error", info, string.format(
        "`%s` is not a name for `n`; it takes a name, `.` or `#id` (rule 1.12.5).", value)) }
    end
    local kind, detail = check_construct(c)
    if not kind then kind, detail = check_implemented(c) end
    if kind then return { fail(kind, info, detail) } end
    local rec, failure = lookup(value)
    if not rec then return { fail(failure.kind, info, failure.detail, failure.hint) } end
    if rec.t ~= "int" and rec.t ~= "float" and rec.t ~= "decimal" then
      return { fail("value error", info, string.format(
        "`n` takes a single number, and `%s` is a %s (rule 1.5.11).", value, kind_name(rec))) }
    end
    local class = "num"
    local explicit = false
    for _, cl in ipairs(c.classes) do if cl == "num" or cl == "pct" then class = cl; explicit = true end end
    if not explicit and S.cfg.governor_class == "pct" then class = "pct" end
    local ok, text, i2 = pcall(print_number, rec, class, c, true)
    if not ok then
      return { fail("value error", info, type(text) == "table" and text.detail or tostring(text)) }
    end
    printed, pinfo = text, i2
    for _, m in ipairs(run_checks(rec, info)) do markers[#markers + 1] = m end
  end
  if #arms > 1 and not english() then
    return { fail("value error", info, string.format(
      "An `n` span with more than one arm needs plural rules for the language `%s`, and weft ships only English (rule 1.6.5).",
      S.lang)) }
  end
  local arm = arms[pick_arm(#arms, pinfo)]
  local out = resolve_arm(arm, with(with(ctx, "hash", printed), "ginfo", pinfo))
  out = wrap_pass(c, out)
  for _, m in ipairs(markers) do out:insert(m) end
  return out
end

local function resolve_span(el, ctx)
  local key, value, many = governor_of(el)
  if not key then return nil end
  local rawkey = get_key(el, key)
  local shown = shown_span(el, rawkey, value)
  local info = info_of(el, ctx, shown)
  local c = analyse(el)
  if many then
    return { fail("construct error", info, "A span takes one governor key (rule 1.5.1).") }
  end
  if key == "if" then return resolve_if(el, value, ctx, shown, info, c) end
  if key == "n" then return resolve_n(el, value, ctx, shown, info, c) end
  -- sign, list, cite: 6f
  if key == "sign" and not (cond.is_name(value) or value:match("^#[%w_.%-]+$")) then
    return { fail("construct error", info, string.format(
      "`%s` is not a name for `sign`; it takes a name or `#id` (rule 1.12.5).", value)) }
  end
  if key == "list" and not cond.is_name(value) then
    return { fail("construct error", info, string.format(
      "`%s` is not a name for `list`; it takes a name (rule 1.12.5).", value)) }
  end
  return { fail("value error", info, string.format(
    "`%s=` on a named value is not available in this version of weft.lua (rule 2.13.3).", key)) }
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

local function hash_text(text, hash)
  if not text:find("#", 1, true) then return text end
  return (text:gsub("#+", function(run)
    local lit = string.rep("#", #run // 2)
    if #run % 2 == 1 then return lit .. hash end
    return lit
  end))
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
      if ctx.hash then out:insert(pandoc.Str(hash_text(el.text, ctx.hash))) else out:insert(el) end
      i = i + 1
    elseif t == "Note" then
      el.content = resolve_blocks(el.content, ctx)
      out:insert(el)
      i = i + 1
    elseif t == "Image" then
      S.stash[#S.stash + 1] = { content = el.content, ctx = ctx }
      el.attributes["weft-cap"] = tostring(#S.stash)
      el.content = pandoc.Inlines({})
      out:insert(el)
      i = i + 1
    elseif INLINE_CONTAINERS[t] then
      if t == "Span" and el.classes:includes("weft-literal") then el.attributes["why"] = nil end
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

resolve_blocks = function(blocks, ctx)
  return blocks:walk({
    traverse = "topdown",
    Div = function(el)
      if el.classes:includes("weft-literal") then el.attributes["why"] = nil end
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
      S.stash[#S.stash + 1] = { caption = el.caption, ctx = ctx }
      el.attr.attributes["weft-cap"] = tostring(#S.stash)
      el.caption = pandoc.Caption({}, nil)
      return el
    end,
    Figure = function(el)
      S.stash[#S.stash + 1] = { caption = el.caption, ctx = ctx }
      el.attr.attributes["weft-cap"] = tostring(#S.stash)
      el.caption = pandoc.Caption({}, nil)
      el.content = resolve_blocks(el.content, with(ctx, "fig", true))
      return el, false
    end,
    Inlines = function(inlines)
      return resolve_inlines(inlines, ctx), false
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
        el.content = resolve_inlines(st.content, st.ctx)
        if st.ctx.fig then S.mute = S.mute - 1 end
        return el
      end
    end,
  })
end

-- ---- lines (N89): tag each construct, before anything is resolved --------------------------------------

local function prev_not_backtick(text, s)
  return s == 1 or text:sub(s - 1, s - 1) ~= "`"
end

local function tag(el)
  if S.src == nil then return nil end
  local needle, ok
  if el.t == "Code" then
    if not code_candidate(el) then return nil end
    needle, ok = "`" .. el.text .. "`{", prev_not_backtick
  elseif el.t == "Span" then
    local key, value = governor_of(el)
    if not key then return nil end
    local rawkey = get_key(el, key)
    needle = string.format('%s="%s"', rawkey, value)
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
  local f = { traverse = "topdown", Inline = tag }
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

local function source_path()
  if quarto and quarto.doc and quarto.doc.input_file then return quarto.doc.input_file end
  local inputs = PANDOC_STATE and PANDOC_STATE.input_files
  if inputs then
    for _, f in ipairs(inputs) do
      if f ~= nil and f ~= "" and f ~= "-" then return f end
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
  S.main = path and (path:gsub("^%./", "")) or nil
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
  local lang = doc.meta.lang
  S.lang = lang ~= nil and pandoc.utils.stringify(lang) or nil
  S.src = path and lines_lib.new(path) or nil
  for _, p in ipairs(problems) do
    record(S.fails, "construct error", { shown = p.key .. ": " .. p.value, idx = nil, chunk = nil },
           string.format("%s: `%s: %s` is not a %s; the default is used (rule 9.1.6).", p.file, p.key, p.value, p.what))
    S.fails[#S.fails].file = p.file
  end

  doc = tag_all(doc)
  local ctx = {}
  local blocks = resolve_blocks(doc.blocks, ctx)
  blocks = restore_captions(blocks)
  local meta = doc.meta
  for _, key in ipairs(META_FIELDS) do
    local v = meta[key]
    local ty = v ~= nil and pandoc.utils.type(v) or nil
    if ty == "Inlines" then meta[key] = resolve_inlines(v, ctx)
    elseif ty == "Blocks" then meta[key] = resolve_blocks(v, ctx) end
  end
  blocks = remove_empty_cells(blocks)
  if S.minus_used and (FORMAT == "latex" or FORMAT == "beamer") then add_minus_declaration(meta) end

  -- the report (N86)
  local draft = truthy_env("WEFT_DRAFT") or cfg.draft == true
  if S.stale then
    io.stderr:write(string.format(
      "weft: the values in %s were published by run %s, not this run (%s): served from freeze or a cache, or by a kernel kept from an earlier render. Their checks did not run now (rule 2.13.8).\n",
      S.main or "this document", S.stale.run, S.stale.current))
  end
  if #S.fails > 0 or #S.warned > 0 then
    io.stderr:write(report.build(S.fails, S.warned))
    local coll = report.collect_path(dir_up_find, quarto ~= nil)
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

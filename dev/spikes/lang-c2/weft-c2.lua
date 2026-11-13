-- weft-c2.lua: a spike resolver for the (c) study. Not the package's filter.
--
-- It reads typed values from two places:
--   * a data block, ````{.weft-values} {json} ````, published once by code (values by name)
--   * an inline carrier, a code span `wv1:<base64url json>` (values by expression)
-- and resolves, on Pandoc's tree, in document order:
--   `name`{.num}  `wv1:...`{.num digits="2"}  `sites`{.and}  `d`{.date}
--   [a | b]{if="name"}  [a | b]{if="slope > 0, n >= 3"}  [x]{if="ok"}  (a guard)
--   [# site | # sites]{n="n"}  with a nested [ | s]{n="."}
-- A failed check, a missing value or an unknown name is collected, a marker is
-- left, and the filter exits 1 once at the end (not when WEFT_DRAFT is set).

local here = pandoc.path.directory(PANDOC_SCRIPT_FILE or "")
local function sibling(name)
  if quarto and quarto.utils and quarto.utils.resolve_path then return quarto.utils.resolve_path(name) end
  return pandoc.path.join({ here, name })
end
local N = dofile(sibling("weftnum.lua"))

local values = {}          -- name -> typed value
local fails = {}
local stats = { constructs = 0, checks = 0, blocks = 0, carriers = 0, discarded = 0 }
local seen_at, seen_run = {}, {}
local NUMBER = { int = true, float = true, dec = true }
local FORMAT = { num = true, pct = true, ["and"] = true, ["or"] = true, date = true, val = true }
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August",
                 "September", "October", "November", "December" }

-- ---- carriers -----------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64(s)
  s = s:gsub("-", "+"):gsub("_", "/")
  local out, bits, nb = {}, 0, 0
  for ch in s:gmatch(".") do
    local idx = B64:find(ch, 1, true)
    if not idx then break end
    bits = (bits << 6) | (idx - 1); nb = nb + 6
    if nb >= 8 then
      nb = nb - 8
      out[#out + 1] = string.char((bits >> nb) & 0xFF)
      bits = bits & ((1 << nb) - 1)
    end
  end
  return table.concat(out)
end

local function note_origin(d)
  if d.at then seen_at[#seen_at + 1] = d.at end
  if d.run ~= nil then seen_run[tostring(d.run)] = true end
end

local function decode_carrier(text)
  local tok = text:match("wv1:([%w_%-]+)")
  if not tok then return nil end
  local ok, d = pcall(pandoc.json.decode, b64(tok), false)
  if not ok or type(d) ~= "table" then return { t = "error", why = "a carrier that cannot be read" } end
  note_origin(d)
  return d
end

-- ---- source lines -----------------------------------------------------------------

local src, inline_lines = nil, {}
local function load_source()
  local path = quarto and quarto.doc and quarto.doc.input_file
  if not path then
    local f = PANDOC_STATE.input_files
    path = f and f[1]
  end
  if not path or path == "-" then return end
  local fh = io.open(path, "r")
  if not fh then return end
  src = fh:read("a"); fh:close()
  -- every inline expression of the source, in order, with its line (not inside a fence)
  local ln, fence = 0, false
  for line in (src .. "\n"):gmatch("(.-)\n") do
    ln = ln + 1
    if line:find("^%s*```") or line:find("^%s*~~~") then fence = not fence
    elseif not fence then
      for _ in line:gmatch("`{%a+}%s") do inline_lines[#inline_lines + 1] = ln end
    end
  end
end

local cursor = {}
local line_start = nil
local function line_of(needle)
  if not src then return nil end
  if not line_start then
    line_start = { 1 }
    for pos in src:gmatch("\n()") do line_start[#line_start + 1] = pos end
  end
  local s, e = src:find(needle, cursor[needle] or 1, true)
  if not s then return nil end
  cursor[needle] = e + 1
  -- binary search in the line starts
  local lo, hi = 1, #line_start
  while lo < hi do
    local mid = (lo + hi + 1) // 2
    if line_start[mid] <= s then lo = mid else hi = mid - 1 end
  end
  return lo
end

local GOV = { "if", "n", "sign", "list" }
local function gov_key(el)
  for _, k in ipairs(GOV) do if el.attributes[k] then return k, el.attributes[k] end end
end

local function is_value(el)
  if el.text:find("^wv1:") then return true end
  for _, c in ipairs(el.classes) do if FORMAT[c] then return true end end
  return false
end

-- before anything is resolved: give every construct its line, chosen arm or not
local carriers_in_tree = {}
local function number_lines(doc)
  load_source()
  local function tag_carrier(el)
    carriers_in_tree[#carriers_in_tree + 1] = el
  end
  doc = doc:walk({
    Inline = function(el)
      if el.t == "Code" and is_value(el) then
        if el.text:find("^wv1:") then tag_carrier(el)
        else el.attributes["weft-line"] = tostring(line_of("`" .. el.text .. "`{") or "") end
        return el
      elseif el.t == "Span" then
        local k, v = gov_key(el)
        if not k then return nil end
        if v:find("wv1:") then tag_carrier(el)
        elseif v ~= "." then el.attributes["weft-line"] = tostring(line_of(k .. '="' .. v .. '"') or "") end
        return el
      end
    end,
  })
  return doc
end

-- ---- failures -----------------------------------------------------------------

local function fail(kind, line, what, detail)
  fails[#fails + 1] = { kind = kind, line = line, what = what, detail = detail }
  local where = (line and line ~= "") and (", line " .. line) or ""
  return pandoc.Str("<<weft: " .. kind .. where .. ">>")
end

local function show(tv)
  if tv.t == "list" then return "a list of " .. #tv.v end
  return tostring(tv.v)
end

-- the checks a value carries count only where the value is used
local function run_checks(tv, line, what)
  local marker
  for _, c in ipairs(tv.checks or {}) do
    stats.checks = stats.checks + 1
    if not c.ok and c.level ~= "warn" then
      marker = fail("failed claim", line, what,
        c.text .. " was false (value " .. show(tv) .. ")" .. (c.why and c.why ~= pandoc.json.null and ("; " .. tostring(c.why)) or ""))
    end
  end
  return marker
end

-- ---- values -----------------------------------------------------------------

local function lookup(expr)
  expr = expr:gsub("`", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if expr:find("^wv1:") then return decode_carrier(expr) end
  if expr:find("^[%a_][%w_.]*$") then
    local tv = values[expr]
    if tv then return tv end
    return { t = "error", why = "no value is published under the name `" .. expr .. "` above this point" }
  end
  return nil
end

local function operand(text)
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text:find("^%-?[%d.]+[eE]?[-+]?%d*$") and N.parse(text) ~= nil then return { t = "dec", v = text } end
  local s = text:match("^'([^']*)'$")
  if s then return { t = "str", v = s } end
  return lookup(text)
end

-- one condition: a name, a carrier, or `a OP b`. Returns true/false, or nil and a typed failure.
local function condition(text)
  local tv = lookup(text)
  if tv then
    if tv.t == "bool" then return tv.v, tv end
    if tv.t == "missing" or tv.t == "error" then return nil, tv end
    return nil, { t = "valueerror", why = "a condition must be true or false, and `" .. text .. "` is a " .. tv.t }
  end
  local a, op, b = text:match("^(.-)%s*([<>=!]=?)%s*(.-)$")
  if not a or op == "=" or op == "!" then
    return nil, { t = "valueerror", why = "`" .. text .. "` is not a name or a comparison the filter can read" }
  end
  local x, y = operand(a), operand(b)
  if not x or not y then
    return nil, { t = "valueerror", why = "`" .. text .. "` is not a name or a comparison the filter can read" }
  end
  for _, o in ipairs({ x, y }) do
    if o.t == "missing" or o.t == "error" then return nil, o end
  end
  if NUMBER[x.t] and NUMBER[y.t] then
    local c = N.compare(x.v, y.v)
    local r = (op == "<" and c < 0) or (op == "<=" and c <= 0) or (op == ">" and c > 0) or
              (op == ">=" and c >= 0) or (op == "==" and c == 0) or (op == "!=" and c ~= 0)
    return r, x
  end
  if x.t == "str" and y.t == "str" and (op == "==" or op == "!=") then
    return (x.v == y.v) == (op == "=="), x
  end
  return nil, { t = "valueerror", why = "`" .. text .. "` compares a " .. x.t .. " with a " .. y.t }
end

local function key_num(el, k)
  local v = el.attributes[k]
  return v and tonumber(v) or nil
end

local function has(el, c) return el.classes:includes(c) end

-- one scalar as text; returns text, info
local function print_scalar(tv, el)
  local opts = { digits = key_num(el, "digits"), sigfig = key_num(el, "sigfig") }
  if NUMBER[tv.t] then
    local v, typ = tv.v, tv.t
    if has(el, "pct") then
      if typ == "float" then v = string.format("%.17g", tonumber(v) * 100)
      else local neg, D, e = N.parse(v); v = (neg and "-" or "") .. D .. "e" .. (e + 2) end
    end
    local txt, info
    if typ == "float" then txt, info = N.print_double(v, opts) else txt, info = N.print_one(v, typ, opts) end
    if has(el, "pct") then txt = txt .. "%" end
    return txt, info
  elseif tv.t == "date" then
    local y, m, d = tv.v:match("^(%d+)-(%d+)-(%d+)$")
    if has(el, "date") and y then return tonumber(d) .. " " .. MONTHS[tonumber(m)] .. " " .. y, {} end
    return tv.v, {}
  elseif tv.t == "str" then return tv.v, {}
  elseif tv.t == "bool" then return nil, { why = "a true or false value has no printed form" } end
  return nil, { why = "a value of type " .. tostring(tv.t) .. " cannot be printed" }
end

local function collapse(items, word)
  if #items == 1 then return items[1] end
  return table.concat(items, ", ", 1, #items - 1) .. " " .. word .. " " .. items[#items]
end

-- a value as inlines; returns inlines, text, info (text nil on failure)
local function print_value(tv, el, what)
  local line = el.attributes["weft-line"]
  if not tv or tv.t == "error" or tv.t == "missing" then
    return pandoc.Inlines({ fail("no value", line, what, tv and tostring(tv.why) or "not a name and not a carrier") })
  end
  local text, info
  if tv.t == "list" then
    if #tv.v == 0 then return pandoc.Inlines({ fail("no value", line, what, "a list of length zero") }) end
    local items = {}
    for i, item in ipairs(tv.v) do
      if item.t == "missing" then return pandoc.Inlines({ fail("no value", line, what, "element " .. i .. " is missing") }) end
      items[i] = print_scalar(item, el)
    end
    text, info = collapse(items, has(el, "or") and "or" or "and"), {}
  else
    text, info = print_scalar(tv, el)
    if not text then return pandoc.Inlines({ fail("value error", line, what, info.why) }) end
  end
  local out = pandoc.Inlines({ pandoc.Str(text) })
  local marker = run_checks(tv, line, what)
  if marker then out:insert(marker) end
  return out, text, info
end

-- ---- spans -----------------------------------------------------------------

local function split_arms(inlines)
  local arms, cur = {}, pandoc.Inlines({})
  for _, el in ipairs(inlines) do
    if el.t == "Str" and el.text == "|" then arms[#arms + 1] = cur; cur = pandoc.Inlines({})
    else cur:insert(el) end
  end
  arms[#arms + 1] = cur
  for _, a in ipairs(arms) do
    while #a > 0 and (a[1].t == "Space" or a[1].t == "SoftBreak") do a:remove(1) end
    while #a > 0 and (a[#a].t == "Space" or a[#a].t == "SoftBreak") do a:remove(#a) end
  end
  return arms
end

local function count_arm(info, n_arms)
  if n_arms == 1 then return 1 end
  local z, o, t = info.zero, info.one, info.two
  if n_arms == 2 then return o and 1 or 2 end
  if n_arms == 3 then return z and 1 or (o and 2 or 3) end
  return z and 1 or (o and 2 or (t and 3 or 4))
end

local resolve_inlines

local function resolve_span(el, ctx)
  local key, val = gov_key(el)
  local line = el.attributes["weft-line"]
  local what = "[" .. pandoc.utils.stringify(el.content):sub(1, 60) .. "]{" .. key .. '="' ..
               (val:find("wv1:") and "(carrier)" or val) .. '"}'
  local arms = split_arms(el.content)
  stats.constructs = stats.constructs + 1
  stats.discarded = stats.discarded + (#arms - 1)
  if key == "if" then
    local all, markers = true, {}
    for cond in (val .. ","):gmatch("%s*([^,]*),") do
      local r, tv = condition(cond)
      if r == nil then
        local kind = (tv.t == "valueerror") and "value error" or "no value"
        return pandoc.Inlines({ fail(kind, line, what, tostring(tv.why)) })
      end
      local m = run_checks(tv, line, what)
      if m then markers[#markers + 1] = m end
      if not r then
        all = false
        if #arms == 1 then markers[#markers + 1] = fail("failed claim", line, what, cond .. " was false (a guard)") end
      end
    end
    local out = resolve_inlines(arms[(all or #arms == 1) and 1 or 2], ctx)
    for _, m in ipairs(markers) do out:insert(m) end
    return out
  elseif key == "n" then
    local info, hash
    if val == "." then
      if not (ctx and ctx.info) then return pandoc.Inlines({ fail("construct error", line, what, 'n="." with no governor around it') }) end
      info, hash = ctx.info, ctx.hash
    else
      local tv = lookup(val)
      if tv and tv.t ~= "error" and tv.t ~= "missing" and not NUMBER[tv.t] then
        return pandoc.Inlines({ fail("value error", line, what, "an n governor must be a single number, not a " .. tv.t) })
      end
      local printed, text, i = print_value(tv, el, what)
      if not text then return printed end
      info, hash = i, text
      local out = resolve_inlines(arms[count_arm(info, #arms)], { info = info, hash = hash })
      if #printed > 1 then out:insert(printed[2]) end   -- a failed claim's marker
      return out
    end
    return resolve_inlines(arms[count_arm(info, #arms)], { info = info, hash = hash })
  end
  return pandoc.Inlines({ fail("construct error", line, what, "the spike does not resolve `" .. key .. "`") })
end

local function is_space(el) return el and (el.t == "Space" or el.t == "SoftBreak") end

resolve_inlines = function(inlines, ctx)
  local out = pandoc.Inlines({})
  local skip = false
  for i, el in ipairs(inlines) do
    if skip then skip = false
    elseif el.t == "Code" and is_value(el) then
      stats.constructs = stats.constructs + 1
      local what = "`" .. (el.text:find("^wv1:") and "(carrier)" or el.text) .. "`{." .. table.concat(el.classes, " .") .. "}"
      out:extend(print_value(lookup(el.text), el, what))
    elseif el.t == "Span" and gov_key(el) then
      local res = resolve_span(el, ctx)
      if #res == 0 then
        -- rule 1.5.20: an empty span takes one space with it
        local nxt = inlines[i + 1]
        local closes = nxt == nil or is_space(nxt) or (nxt.t == "Str" and nxt.text:find("^[%].,;:!?)]"))
        if is_space(out[#out]) and closes then out:remove(#out)
        elseif #out == 0 and is_space(nxt) then skip = true end
      else out:extend(res) end
    elseif el.t == "Str" and ctx and ctx.hash and el.text:find("#", 1, true) then
      out:insert(pandoc.Str((el.text:gsub("#", (ctx.hash:gsub("%%", "%%%%"))))))
    else
      if el.content and pandoc.utils.type(el.content) == "Inlines" then el.content = resolve_inlines(el.content, ctx) end
      out:insert(el)
    end
  end
  return out
end

-- ---- the filter -----------------------------------------------------------------

local function read_block(el)
  local ok, d = pcall(pandoc.json.decode, el.text, false)
  if not ok or type(d) ~= "table" or type(d.values) ~= "table" then
    fail("construct error", nil, "a weft-values block", "the block is not JSON with a `values` object")
    return
  end
  stats.blocks = stats.blocks + 1
  note_origin(d)
  for k, tv in pairs(d.values) do values[k] = tv end
end

local function json_str(s) return pandoc.json.encode(tostring(s)) end

local function report(doc)
  local now = os.time()
  local oldest
  for _, t in ipairs(seen_at) do if not oldest or t < oldest then oldest = t end end
  local runs = {}
  for r in pairs(seen_run) do runs[#runs + 1] = r end
  local want = os.getenv("WEFT_RUN")
  local age = oldest and (now - oldest) or nil
  local served = age and age > 120
  io.stderr:write(string.format(
    "weft-c2: %d constructs, %d checks, %d data block(s), %d arm(s) discarded unread; values are %s old%s\n",
    stats.constructs, stats.checks, stats.blocks, stats.discarded,
    age and (age .. " s") or "of unknown age",
    served and " (not executed in this render: frozen or cached)" or ""))
  local f = io.open(os.getenv("WEFT_STAMP") or "weft-c2-stamp.json", "w")
  if f then
    f:write(string.format('{"constructs":%d,"checks":%d,"failures":%d,"values_age_s":%s,"runs":%s,"want_run":%s,"executed_now":%s}\n',
      stats.constructs, stats.checks, #fails, age or "null", pandoc.json.encode(runs),
      want and json_str(want) or "null", tostring(not served)))
    f:close()
  end
  if #fails == 0 then return nil end
  local file = (quarto and quarto.doc and quarto.doc.input_file) or (PANDOC_STATE.input_files[1] or "")
  io.stderr:write(string.format("weft: %d failure(s)\n", #fails))
  for _, x in ipairs(fails) do
    io.stderr:write(string.format("  %s:%s  %s\n      %s: %s\n", file:match("[^/]*$"), (x.line and x.line ~= "") and x.line or "?",
      x.what, x.kind, x.detail))
  end
  if os.getenv("WEFT_DRAFT") then return nil end
  os.exit(1)
end

return {
  { Meta = function(m)
      local w = m.weft
      if type(w) == "table" and w.digits then N.cfg.digits = tonumber(pandoc.utils.stringify(w.digits)) end
    end },
  { Pandoc = function(doc)
      doc = number_lines(doc)
      -- an inline carrier's line: the k-th carrier is the k-th inline expression of the source
      if #carriers_in_tree > 0 and #carriers_in_tree == #inline_lines then
        local k = 0
        doc = doc:walk({ Inline = function(el)
          if (el.t == "Code" and el.text:find("^wv1:")) or (el.t == "Span" and gov_key(el) and select(2, gov_key(el)):find("wv1:")) then
            k = k + 1
            el.attributes["weft-line"] = tostring(inline_lines[k])
            return el
          end
        end })
      end
      stats.carriers = #carriers_in_tree
      return doc
    end },
  { Pandoc = function(doc)
      -- the body first, in document order; then the front matter, with what the body published
      doc.blocks = doc.blocks:walk({
        traverse = "topdown",
        CodeBlock = function(el)
          if el.classes:includes("weft-values") then read_block(el); return {} end
        end,
        Inlines = function(inlines) return resolve_inlines(inlines, nil), false end })
      for k, val in pairs(doc.meta) do
        if pandoc.utils.type(val) == "Inlines" then doc.meta[k] = resolve_inlines(val, nil) end
      end
      return doc
    end },
  { Div = function(el)
      if #el.content == 0 and (el.classes:includes("cell-output") or el.classes:includes("cell")) then return {} end
    end,
    Pandoc = report },
}

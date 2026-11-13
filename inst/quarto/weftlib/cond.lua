-- weftlib/cond.lua: the condition grammar of `if` (dev/design-6.md N9 to N11, E3, E4, E18, E19).
--
--   local cond = dofile("weftlib/cond.lua")
--   nodes, err = cond.parse(value)      -- value: the text of an `if` attribute
--   ok, reads  = cond.evaluate(node, get)
--
-- parse() splits the value at every comma outside a single-quoted string and reads each part as a
-- NAME, or as OPERAND OP OPERAND (one comparison). It returns an array of nodes, or nil and
-- {id = "E3" | "E4", part = <the part as written, trimmed>}.
--
-- evaluate() takes get(name), which returns a record or nil and a failure table
-- {kind = "no value" | "value error", detail = <text>, hint = <text or nil>}. It returns true or
-- false and the records it read (so the caller can count their checks), or nil and a failure table
-- of the same shape. Numbers are compared on the decimal text of the record, exactly: no double
-- decides a comparison. No side effect on load.

local M = {}

M.RESERVED = {}
for w in ([[TRUE FALSE True False true false NA NULL None nothing missing Inf NaN]]):gmatch("[^ \t\r\n]+") do
  M.RESERVED[w] = true
end

function M.is_name(s)
  if type(s) ~= "string" or #s > 64 then return false end
  if not s:match("^[A-Za-z_][A-Za-z0-9_.]*$") then return false end
  if s:sub(-1) == "." then return false end
  return not M.RESERVED[s]
end

-- a valid YYYY-MM-DD calendar date (leap years by the Gregorian rule)
function M.valid_date(v)
  if type(v) ~= "string" then return false end
  local y, m, d = v:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then return false end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if m < 1 or m > 12 or d < 1 then return false end
  local dim = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 then dim[2] = 29 end
  return d <= dim[m]
end

local function trim(s) return (s:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", "")) end

-- split at every comma that is not inside a single-quoted string
function M.split(value)
  local parts, cur, inq = {}, {}, false
  for i = 1, #value do
    local c = value:sub(i, i)
    if c == "'" then inq = not inq end
    if c == "," and not inq then
      parts[#parts + 1] = table.concat(cur)
      cur = {}
    else
      cur[#cur + 1] = c
    end
  end
  parts[#parts + 1] = table.concat(cur)
  return parts
end

-- an operand carries no whitespace of its own: only a space or a tab may stand around the operator (R's rule)
local function operand(text)
  if text:match("^'[^'\\]*'$") then return { str = text:sub(2, -2) } end
  if text:match("^%-?%d+$") or text:match("^%-?%d+%.%d+$") or text:match("^%-?%d+[eE][+-]?%d+$")
     or text:match("^%-?%d+%.%d+[eE][+-]?%d+$") then
    return { num = text }
  end
  if M.is_name(text) then return { name = text } end
  return nil
end

-- the first comparison character outside a string, and its operator
local function find_op(text)
  local inq = false
  for i = 1, #text do
    local c = text:sub(i, i)
    if c == "'" then inq = not inq
    elseif not inq and (c == "<" or c == ">" or c == "=" or c == "!") then
      local two = text:sub(i, i + 1)
      if two == "<=" or two == ">=" or two == "==" or two == "!=" then return i, two end
      if c == "<" or c == ">" then return i, c end
      return i, nil          -- a lone = or !: not an operator of the grammar
    end
  end
  return nil
end

local function has_compare_char(text)
  local inq = false
  for i = 1, #text do
    local c = text:sub(i, i)
    if c == "'" then inq = not inq
    elseif not inq and (c == "<" or c == ">" or c == "=" or c == "!") then return true end
  end
  return false
end

function M.parse_part(raw)
  local text = trim(raw)
  if text == "" then return nil, { id = "E3", part = text } end
  -- `!NAME`: the negation of one bool name; `!` before anything else is not in the grammar
  local negated = text:match("^!([A-Za-z_][A-Za-z0-9_.]*)$")
  if negated and M.is_name(negated) then
    return { text = text, neg = true, a = { name = negated } }
  end
  local i, op = find_op(text)
  if not i then
    if M.is_name(text) then return { text = text, a = { name = text } } end
    return nil, { id = "E3", part = text }
  end
  if not op then return nil, { id = "E3", part = text } end
  local left, right = text:sub(1, i - 1):gsub("[ \t]+$", ""), text:sub(i + #op):gsub("^[ \t]+", "")
  if has_compare_char(right) then return nil, { id = "E3", part = text } end
  local a, b = operand(left), operand(right)
  if not a or not b then return nil, { id = "E3", part = text } end
  if not a.name and not b.name then return nil, { id = "E4", part = text } end
  return { text = text, op = op, a = a, b = b }
end

-- the text of the E3 and E4 error of a part (rule 1.12.4); err is the second value of parse()
function M.message(err)
  if err.id == "E4" then
    return string.format("`%s` compares two literals and has no name, so it is always the same (rule 1.12.4).", err.part)
  end
  return string.format("`%s` is not a name or one comparison of names, numbers and 'strings'; bind the condition to a name in code (rule 1.12.4).", err.part)
end

function M.parse(value)
  local nodes = {}
  for _, p in ipairs(M.split(value)) do
    local node, err = M.parse_part(p)
    if not node then return nil, err end
    nodes[#nodes + 1] = node
  end
  return nodes
end

-- ---- evaluation ----------------------------------------------------------------------------------

-- a decimal text as sign, digits (no leading or trailing zeros) and exponent: value = digits * 10^exp
local function dec(s)
  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end
  local mant, ex = s:match("^([^eE]*)[eE]([+-]?%d+)$")
  if mant then ex = math.tointeger(tonumber(ex)) or 0 else mant, ex = s, 0 end
  local ip, fp = mant:match("^(%d+)%.?(%d*)$")
  if not ip then return 0, "", 0 end
  local digits = (ip .. fp):gsub("^0+", "")
  local e = ex - #fp
  if digits == "" then return 0, "", 0 end
  local trimmed = digits:gsub("0+$", "")
  e = e + (#digits - #trimmed)
  return neg and -1 or 1, trimmed, e
end

-- -1, 0 or 1
function M.num_cmp(a, b)
  local sa, da, ea = dec(a)
  local sb, db, eb = dec(b)
  if sa ~= sb then return sa < sb and -1 or 1 end
  if sa == 0 then return 0 end
  local ma, mb = #da + ea, #db + eb
  local c
  if ma ~= mb then c = ma < mb and -1 or 1
  else
    local n = math.max(#da, #db)
    local pa, pb = da .. string.rep("0", n - #da), db .. string.rep("0", n - #db)
    c = pa == pb and 0 or (pa < pb and -1 or 1)
  end
  return c * sa
end

local KIND_NAME = { int = "integer" }
local function kind_name(k) return KIND_NAME[k] or k end
M.kind_name = kind_name

local function category(v)
  -- v: {rec = record} or a literal operand
  if v.num then return "number", v.num end
  if v.str then return "string", v.str end
  local t = v.rec.t
  if t == "int" or t == "float" or t == "decimal" then return "number", v.rec.v end
  if t == "string" then return "string", v.rec.v end
  if t == "date" then return "date", v.rec.v end
  if t == "bool" then return "bool", v.rec.v end
  return t, nil
end

local function shown_kind(v)
  if v.num then return "number" end
  if v.str then return "string" end
  return kind_name(v.rec.t)
end

local function value_error(detail) return nil, { kind = "value error", detail = detail } end

function M.evaluate(node, get)
  local reads = {}
  local function fetch(o)
    if o.name then
      local rec, failure = get(o.name)
      if not rec then return nil, failure end
      reads[#reads + 1] = rec
      return { rec = rec, name = o.name }
    end
    return o
  end
  local a, fa = fetch(node.a)
  if not a then return nil, fa end
  if not node.op then
    if a.rec.t ~= "bool" then
      return value_error(string.format(
        "a condition must be true or false, and `%s` is a %s (rule 1.11.8).", node.a.name, kind_name(a.rec.t)))
    end
    if node.neg then return a.rec.v ~= true, reads end
    return a.rec.v == true, reads
  end
  local b, fb = fetch(node.b)
  if not b then return nil, fb end
  local ca, va = category(a)
  local cb, vb = category(b)
  local op = node.op
  local c
  if ca == "number" and cb == "number" then
    c = M.num_cmp(va, vb)
  elseif ca == "string" and cb == "string" then
    if op ~= "==" and op ~= "!=" then
      return value_error(string.format(
        "`%s` orders two strings; strings compare only with == and != (rule 1.12.5).", node.text))
    end
    c = va == vb and 0 or 1
  elseif ca == "date" and cb == "date" then
    c = va == vb and 0 or (va < vb and -1 or 1)
  elseif (ca == "date" and b.str) or (cb == "date" and a.str) then
    -- a date against a string literal: calendar order when the literal is a valid YYYY-MM-DD date
    local lit = b.str or a.str
    if not M.valid_date(lit) then
      return value_error(string.format(
        "`%s` compares a date with the string '%s', which is not a YYYY-MM-DD date (rule 1.12.5).", node.text, lit))
    end
    c = va == vb and 0 or (va < vb and -1 or 1)
  elseif ca == "bool" and cb == "bool" and (op == "==" or op == "!=") then
    c = va == vb and 0 or 1
  else
    return value_error(string.format("`%s` compares a %s with a %s (rule 1.12.5).",
                                     node.text, shown_kind(a), shown_kind(b)))
  end
  local r
  if op == "<" then r = c < 0 elseif op == "<=" then r = c <= 0 elseif op == ">" then r = c > 0
  elseif op == ">=" then r = c >= 0 elseif op == "==" then r = c == 0 else r = c ~= 0 end
  return r, reads
end

return M

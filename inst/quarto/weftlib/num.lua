-- weftlib/num.lua: the number printer of the filter (dev/design-6.md, N85).
--
--   local num = dofile("weftlib/num.lua")
--   text, info = num.format(record, class, keys, config)
--
-- record  the decoded JSON record of schema 1: {t = "float"|"int"|"decimal", v = "<text>"}
-- class   "num" or "pct" (no dot); nothing else is implemented
-- keys    table or nil: digits, sigfig (Lua numbers); any other key is not implemented
-- config  table or nil: digits, decimal_mark, big_mark, thousands_from, minus; target ("markdown", the
--         default, or "tex": the forms a formula holds, dev/design-9.md TX4 to TX6; the minus is "-", the
--         marks are converted, a percent sign is \%, and sci and p write TeX). Without a target the text is
--         what it was before the target existed.
--
-- info.ip is the integer part of the printed number as digits (no sign, no group marks).
-- Doubles (kind "float") go through a literal port of round_half_away(), fixed_text(),
-- print_one() and zero_noise() of R/format.R: the same IEEE doubles and the same C printf, so
-- the text is R's text. Integers and exact decimals (kinds "int" and "decimal") go through an
-- exact algorithm on the digit string; no double decides a digit. Anything not implemented
-- calls error(); nothing is passed through. No side effect on load: no global is set.

local M = {}

local DEFAULTS = {
  digits = 1, decimal_mark = ".", big_mark = ",", thousands_from = 1000, minus = "\u{2212}",
}
local MAX_PLACES = 100      -- as R's MAX_PLACES
local MAX_EXP = 100000      -- an exact decimal with a larger exponent is refused, not expanded

-- Quarto redefines the global `error` to log and return; assert() is left alone
local function fail(fmt, ...) assert(false, string.format(fmt, ...)) end

-- ---- configuration -------------------------------------------------------------------------

-- ---- the TeX target (dev/design-9.md TX4 to TX6; the same text as tex_text() and tex_cfg() of R/tex.R) ----

local TEX_SPECIAL = {
  ["\\"] = "\\backslash", ["{"] = "\\{", ["}"] = "\\}", ["$"] = "\\$", ["%"] = "\\%", ["&"] = "\\&",
  ["#"] = "\\#", ["_"] = "\\_", ["^"] = "\\hat{}", ["~"] = "\\sim", ["<"] = "<", [">"] = ">", ["|"] = "|",
  ["\u{a0}"] = "\\,",
}

-- Maximal runs of ordinary characters go in \text{}; each special character maps singly.
function M.tex_text(str)
  if str == "" then return "" end
  local out, run = {}, {}
  local function flush()
    if #run > 0 then out[#out + 1] = "\\text{" .. table.concat(run) .. "}"; run = {} end
  end
  for ch in str:gmatch(utf8.charpattern) do
    local t = TEX_SPECIAL[ch]
    if t then flush(); out[#out + 1] = t else run[#run + 1] = ch end
  end
  flush()
  return table.concat(out)
end

local function tex_mark(mark)
  if mark == "" then return "" end
  if mark == "," then return "{,}" end
  if mark == "." then return "." end
  if mark == " " or mark == "\u{a0}" or mark == "\u{2009}" or mark == "\u{202f}" then return "\\," end
  if mark == "'" or mark == "\u{2019}" then return "\\text{'}" end
  if mark == "\u{b7}" then return "{\\cdot}" end
  return M.tex_text(mark)
end

-- the setting p_label under TeX: one ASCII letter, bare or inside one pair of * or _, is the letter;
-- anything else is text
local function tex_p_label(label)
  if label == "" then return "" end
  if label:match("^[A-Za-z]$") then return label end
  local m = label:match("^%*([A-Za-z])%*$") or label:match("^_([A-Za-z])_$")
  if m then return m end
  return M.tex_text(label)
end

local function read_config(config)
  local cfg = {}
  for k, v in pairs(DEFAULTS) do cfg[k] = v end
  if config == nil then return cfg end
  if type(config) ~= "table" then fail("config is not a table (got %s)", type(config)) end
  for k, v in pairs(config) do
    if DEFAULTS[k] ~= nil then
      if type(DEFAULTS[k]) == "number" then
        local n = tonumber(v)
        if n == nil then fail("config %s must be a number (got %s)", k, tostring(v)) end
        cfg[k] = n
      else
        if type(v) ~= "string" then fail("config %s must be a string (got %s)", k, tostring(v)) end
        cfg[k] = v
      end
    end
  end
  cfg.digits = math.floor(cfg.digits)
  if cfg.digits < 0 then fail("config digits must not be negative") end
  local target = config.target
  if target ~= nil and target ~= "markdown" then
    if target ~= "tex" then fail("config target must be \"markdown\" or \"tex\" (got %s)", tostring(target)) end
    local big, dec = tex_mark(cfg.big_mark), tex_mark(cfg.decimal_mark)
    if dec ~= "" and dec == big then dec = "\\text{" .. cfg.decimal_mark .. "}" end
    cfg.minus, cfg.big_mark, cfg.decimal_mark = "-", big, dec
    cfg.tex = true
  end
  return cfg
end

-- ---- shared text helpers -------------------------------------------------------------------

-- insert `mark` between groups of three digits, counted from the right
local function group_int(digits, mark)
  if mark == "" or #digits <= 3 then return digits end
  local parts = {}
  local first = #digits % 3
  if first > 0 then parts[#parts + 1] = digits:sub(1, first) end
  for i = first + 1, #digits, 3 do parts[#parts + 1] = digits:sub(i, i + 2) end
  return table.concat(parts, mark)
end

-- ---- the literal port of R's double algorithm ------------------------------------------------

local function nearbyint(x)       -- round half to even
  local f = math.floor(x)
  local d = x - f
  if d > 0.5 then return f + 1 elseif d < 0.5 then return f end
  return (f % 2 == 0) and f or f + 1
end

-- R_pow_di (nmath): repeated squaring, as R does it
local function pow_di(x, n)
  local xn = 1.0
  if n ~= 0 then
    local neg = n < 0
    if neg then n = -n end
    while true do
      if n % 2 == 1 then xn = xn * x end
      n = n // 2
      if n ~= 0 then x = x * x else break end
    end
    if neg then xn = 1.0 / xn end
  end
  return xn
end

-- R's signif() (nmath/fprec.c) for finite x > 0
local MAX10E, MAXDIG = 308, 22
local function signif(x, dig)
  if x == 0 or x == math.huge then return x end
  local l10 = math.log(x, 10)
  local e10 = math.tointeger(dig - 1 - math.floor(l10))
  if math.abs(l10) < MAX10E - 2 then
    local p10 = 1.0
    if e10 > MAX10E then p10 = pow_di(10.0, e10 - MAX10E); e10 = MAX10E end
    if e10 > 0 then
      local pow10 = pow_di(10.0, e10)
      return (nearbyint((x * pow10) * p10) / pow10) / p10
    else
      local pow10 = pow_di(10.0, -e10)
      return nearbyint(x / pow10) * pow10
    end
  else
    local do_round = (MAX10E - l10) >= pow_di(10.0, -dig)
    local e2 = dig + ((e10 > 0) and 1 or -1) * MAXDIG
    local p10 = pow_di(10.0, e2)
    x = x * p10
    local P10 = pow_di(10.0, e10 - e2)
    x = x * P10
    if do_round then x = x + 0.5 end
    x = math.floor(x) / p10
    return x / P10
  end
end

local TWO53 = 2.0 ^ 53

-- signif(y, 15) with the decade taken from the exact decimal expansion (see signif15 in R/format.R)
local function signif15(y)
  local e_true = math.tointeger(tonumber(string.format("%.25e", y):match("e(.*)$")))
  return signif(y, math.tointeger(15 + (math.floor(math.log(y, 10)) - e_true)))
end

local function round_half_away(x, nd)
  if x == 0 then return 0.0 end
  local sgn = (x < 0) and -1.0 or 1.0
  local a = math.abs(x)
  if nd >= 0 and a <= TWO53 and a == math.floor(a) then return x end
  local r
  if nd >= 0 then
    local y = a * 10.0 ^ nd
    if y == math.huge then return x end
    r = math.floor(signif15(y) + 0.5) / 10.0 ^ nd
  else
    local p = 10.0 ^ (-nd)
    r = math.floor(signif15(a / p) + 0.5) * p
  end
  return sgn * r
end

local function fixed_text(a, nd)
  if nd > 99 then fail("digits above 99 are not implemented for a float record") end
  local f = "%." .. string.format("%d", nd) .. "f"
  if a <= TWO53 then return string.format(f, a) end
  local e = string.format("%.14e", a)
  local mant, ex = e:match("^([^e]*)e(.*)$")
  ex = math.tointeger(tonumber(ex))
  local dig = mant:gsub("%.", "", 1)
  if ex < 14 then return string.format(f, a) end
  local int = dig .. string.rep("0", ex - 14)
  if nd > 0 then return int .. "." .. string.rep("0", nd) end
  return int
end

local function is_whole(v)
  return math.abs(v - nearbyint(v)) < 1e-9
end

-- returns {text, number, decimals}
local function print_one(v, digits, sigfig, cfg)
  local s, nd
  if sigfig then
    if v == 0 then s = 0.0 else
      s = round_half_away(v, sigfig - 1 - math.floor(math.log(math.abs(v), 10)))
    end
    if s == 0 then nd = sigfig - 1
    else nd = math.max(sigfig - 1 - math.floor(math.log(math.abs(s), 10)), 0) end
  elseif digits then
    nd = digits
    s = round_half_away(v, nd)
  else
    nd = is_whole(v) and 0 or cfg.digits
    s = round_half_away(v, nd)
  end
  nd = math.tointeger(nd)
  local str = fixed_text(math.abs(s), nd)
  local num = tonumber(str) * 1.0
  local neg = s < 0 and num ~= 0
  local int, frac = str:match("^([^.]*)%.?(.*)$")
  local ip = int
  if num >= cfg.thousands_from then int = group_int(int, cfg.big_mark) end
  local txt = int
  if frac ~= "" then txt = int .. cfg.decimal_mark .. frac end
  if neg then
    txt = cfg.minus .. txt
    num = -num
  end
  return { text = txt, number = num, decimals = nd > 0, ip = ip }
end

-- R's zero_noise(): digits past the fifteenth print as zeros
local function zero_noise(p, cfg)
  local keep = 15
  local txt = p.text
  local dm = cfg.decimal_mark
  local at = (dm == "") and nil or txt:find(dm, 1, true)
  if not p.decimals or at == nil or p.number ~= p.number or math.abs(p.number) == math.huge then
    return txt
  end
  local head = txt:sub(1, at - 1)
  local frac = txt:sub(at + #dm)
  local lead = head:match("^[^0-9]*")
  local all_digits = (head:gsub("[^0-9]", "") .. frac:gsub("[^0-9]", "")):gsub("^0+", "")
  if #all_digits <= keep then return txt end
  local x = math.abs(p.number)
  local r = string.format("%." .. (keep - 1) .. "e", x)
  local mant, ex = r:match("^([^e]*)e(.*)$")
  local ds = mant:gsub("%.", "")
  local E = math.tointeger(tonumber(ex))
  if x == 0 or E + 1 >= keep then return txt end
  local ip, fp
  if E >= 0 then
    ip = ds:sub(1, E + 1)
    fp = ds:sub(E + 2)
  else
    ip = "0"
    fp = string.rep("0", -E - 1) .. ds
  end
  local nd = #frac
  fp = (fp .. string.rep("0", nd)):sub(1, nd)
  if x >= cfg.thousands_from then ip = group_int(ip, cfg.big_mark) end
  return lead .. ip .. dm .. fp
end

local function print_float(text, class, digits, sigfig, cfg)
  local v = tonumber(text) * 1.0
  if v ~= v or v == math.huge or v == -math.huge then
    fail("float record with a value that is not finite")
  end
  local sv = (class == "pct") and v * 100 or v
  local p = print_one(sv, digits, sigfig, cfg)
  p.text = zero_noise(p, cfg)
  if class == "pct" then p.text = p.text .. (cfg.tex and "\\%" or "%") end
  return p.text, p.number, p.decimals, p.ip
end

-- ---- the exact algorithm on a digit string ---------------------------------------------------
-- A number is a sign, a digit string D without leading zeros ("0" for zero) and an exponent e:
-- value = D * 10^e.

local function parse_exact(text)
  local neg = false
  local s = text
  if s:sub(1, 1) == "-" then neg = true; s = s:sub(2) end
  local mant, ex = s:match("^([0-9.]+)[eE]([-+]?[0-9]+)$")
  if not mant then mant, ex = s, "0" end
  local ip, fp = mant:match("^([0-9]+)%.([0-9]+)$")
  if not ip then ip, fp = mant, "" end
  local e = tonumber(ex)
  if math.abs(e) > MAX_EXP then fail("a number with an exponent beyond %d is not implemented", MAX_EXP) end
  local D = (ip .. fp):gsub("^0+", "")
  e = math.tointeger(e) - #fp
  if D == "" then return neg, "0", 0 end
  return neg, D, e
end

local function inc(D)
  local t, carry = {}, 1
  for i = #D, 1, -1 do
    local d = D:byte(i) - 48 + carry
    if d == 10 then t[i] = "0"; carry = 1 else t[i] = string.char(48 + d); carry = 0 end
  end
  return (carry == 1 and "1" or "") .. table.concat(t)
end

-- drop the last k digits of D, rounding half away from zero on the magnitude
local function drop(D, e, k)
  if k <= 0 then return D, e end
  if #D < k + 1 then D = string.rep("0", k + 1 - #D) .. D end
  local keep, nxt = D:sub(1, #D - k), D:byte(#D - k + 1) - 48
  if nxt >= 5 then keep = inc(keep) end
  keep = keep:gsub("^0+", "")
  if keep == "" then keep = "0" end
  return keep, e + k
end

local function round_places(D, e, nd) return drop(D, e, -nd - e) end

-- fixed notation with nd >= 0 decimals, after round_places(): integer part and fraction
local function fixed(D, e, nd)
  if D == "0" then return "0", string.rep("0", nd) end
  if e > 0 then D = D .. string.rep("0", e); e = 0 end
  if -e < nd then D = D .. string.rep("0", nd + e); e = -nd end
  if #D <= nd then D = string.rep("0", nd - #D + 1) .. D end
  return D:sub(1, #D - nd), D:sub(#D - nd + 1)
end

local function print_exact(text, class, digits, sigfig, cfg)
  local neg, D, e = parse_exact(text)
  if class == "pct" then e = e + 2 end
  local nd
  if sigfig then
    if D ~= "0" then D, e = round_places(D, e, sigfig - 1 - (#D + e - 1)) end
    nd = (D == "0") and (sigfig - 1) or math.max(sigfig - 1 - (#D + e - 1), 0)
    D, e = round_places(D, e, nd)
  elseif digits then
    nd = digits
    D, e = round_places(D, e, nd)
  else
    -- whole when no fraction digit is other than 0
    local whole
    if D == "0" or e >= 0 then whole = true
    elseif #D <= -e then whole = false
    else whole = not D:sub(#D + e + 1):find("[1-9]") end
    nd = whole and 0 or cfg.digits
    D, e = round_places(D, e, nd)
  end
  local ip, fp = fixed(D, e, nd)
  local zero = not (ip .. fp):find("[1-9]")
  local shown = ip
  local from = cfg.thousands_from
  if from ~= math.huge then
    from = string.format("%.0f", math.ceil(from))
    if #ip > #from or (#ip == #from and ip >= from) then shown = group_int(ip, cfg.big_mark) end
  end
  local txt = shown
  if nd > 0 then txt = txt .. cfg.decimal_mark .. fp end
  if neg and not zero then txt = cfg.minus .. txt end
  if class == "pct" then txt = txt .. (cfg.tex and "\\%" or "%") end
  local number = 0.0
  if not zero then
    number = tonumber(ip .. (nd > 0 and ("." .. fp) or "")) * 1.0
    if neg then number = -number end
  end
  return txt, number, nd > 0, ip
end

-- ---- the entry point ---------------------------------------------------------------------------

local function key_number(keys, name)
  local v = keys[name]
  if v == nil then return nil end
  local n = tonumber(v)
  if n == nil or n ~= math.floor(n) or n < 0 then
    fail("key %s must be a whole number, not negative (got %s)", name, tostring(v))
  end
  if n > MAX_PLACES then fail("key %s must be at most %d (got %s)", name, MAX_PLACES, tostring(v)) end
  return math.tointeger(n)
end

local function plain_number(v)   -- digits, optional fraction, optional exponent
  return v:match("^%-?[0-9]+$") or v:match("^%-?[0-9]+%.[0-9]+$")
      or v:match("^%-?[0-9]+%.[0-9]+[eE][-+]?[0-9]+$") or v:match("^%-?[0-9]+[eE][-+]?[0-9]+$")
end

-- ---- .sci and .p (dev/design-6.md N100) ---------------------------------------------------------------
-- Separate entry points: M.format answers only num and pct. Both read the record as R reads it, as a
-- double (as.numeric), and port sci_one() and print_p() of R/format.R as they are.

local function scalar_double(record, what)
  if type(record) ~= "table" then fail("record is not a table (got %s)", record == nil and "nil" or type(record)) end
  local kind = record.t
  if kind ~= "float" and kind ~= "int" and kind ~= "decimal" then
    fail("record kind %s is not implemented by %s (only float, int and decimal)", tostring(kind), what)
  end
  local v = tonumber(record.v)
  if v == nil or type(record.v) ~= "string" then fail("malformed %s record: v = %q", kind, tostring(record.v)) end
  v = v * 1.0
  if v ~= v or v == math.huge or v == -math.huge then fail("%s record with a value that is not finite", kind) end
  return v
end

local function key_count(keys, name)
  keys = keys or {}
  local d, s = key_number(keys, "digits"), key_number(keys, "sigfig")
  if d and s then fail("keys digits and sigfig cannot be used together") end
  if s and s < 1 then fail("key sigfig must be at least 1") end
  return d, s
end

-- scientific notation: "1.2 x 10^4^" (a multiplication sign, the exponent in carets). Returns text and
-- {number, decimals, relation}.
function M.format_sci(record, keys, config)
  local v = scalar_double(record, "the .sci printer")
  local digits, sigfig = key_count(keys)
  local cfg = read_config(config)
  if v == 0 then
    -- zero has no exponent; its mantissa is printed by the usual rule (negative zero is zero)
    local z = print_one(0.0, digits, sigfig, cfg)
    return z.text, { number = 0.0, decimals = z.decimals, relation = "=" }
  end
  local e = math.floor(math.log(math.abs(v), 10))
  -- 10^e is split in two so that a denormal number does not underflow
  local h = e // 2
  local m = (v == 0) and 0.0 or (v / 10.0 ^ h) / 10.0 ^ (e - h)
  local p = print_one(m, digits, sigfig, cfg)
  if math.abs(p.number) >= 10 then
    -- a rounding carry: the mantissa is an exact 1, printed like a typed power of ten
    e = e + 1
    p = print_one((m < 0) and -1.0 or 1.0, digits, sigfig, cfg)
  end
  local ei = math.tointeger(e) or math.floor(e)
  local exp_txt = (ei < 0) and (cfg.minus .. string.format("%d", -ei)) or string.format("%d", ei)
  local h2 = e // 2
  local sci_text = cfg.tex and (p.text .. " \\times 10^{" .. exp_txt .. "}")
    or (p.text .. " \u{d7} 10^" .. exp_txt .. "^")
  return sci_text, {
    number = (p.number * 10.0 ^ h2) * 10.0 ^ (e - h2), decimals = p.decimals, relation = "=",
  }
end

-- a p-value: "p < 0.001", "p > 0.99", three decimals below 0.1, two from there. A value outside 0 to 1
-- calls error() with R's text.
function M.format_p(record, config, keys)
  local v = scalar_double(record, "the .p printer")
  local cfg = read_config(config)
  keys = keys or {}
  config = config or {}
  if v < 0 or v > 1 then fail("`.p` needs a value from 0 to 1; got %s.", string.format("%.15g", v)) end
  local label = keys.label
  if label == nil then
    label = config.p_label
    if label == nil then label = "p" end
    if cfg.tex then label = tex_p_label(label) end
  end
  local function mk(str, rel, number)
    local s = str:gsub("%.", function() return cfg.decimal_mark end, 1)
    local lead
    if label ~= "" then lead = label .. " " .. rel .. " "
    elseif rel == "=" then lead = ""
    else lead = rel .. " " end
    return lead .. s, { number = number, decimals = true, relation = rel }
  end
  local d = keys.digits
  if d == nil then d = config.p_digits end
  if d ~= nil then
    d = math.tointeger(tonumber(d))
    if d == nil or d < 1 or d > 6 then fail("`digits` on `.p` must be a whole number from 1 to 6.") end
    local unit = 10.0 ^ -d
    if v < unit * (1 - 1e-9) then
      local s = "0." .. string.rep("0", d - 1) .. "1"
      return mk(s, "<", tonumber(s))
    end
    if round_half_away(v, d) >= 1 then
      local s = "0." .. string.rep("9", d)
      return mk(s, ">", tonumber(s))
    end
    local s = string.format("%." .. d .. "f", round_half_away(v, d))
    return mk(s, "=", tonumber(s))
  end
  if v < 0.001 then return mk("0.001", "<", 0.001) end
  if v > 0.99 then return mk("0.99", ">", 0.99) end
  local s3 = round_half_away(v, 3)
  if s3 < 0.1 then
    local s = string.format("%.3f", s3)
    return mk(s, "=", tonumber(s))
  end
  local s = string.format("%.2f", round_half_away(v, 2))
  return mk(s, "=", tonumber(s))
end

function M.format(record, class, keys, config)
  if class ~= "num" and class ~= "pct" then
    fail("class %s is not implemented by the number printer (only num and pct)", tostring(class))
  end
  keys = keys or {}
  if type(keys) ~= "table" then fail("keys is not a table (got %s)", type(keys)) end
  local names = {}
  for k in pairs(keys) do names[#names + 1] = tostring(k) end
  table.sort(names)
  for _, k in ipairs(names) do
    if k ~= "digits" and k ~= "sigfig" and k ~= "plus" then
      fail("key %s is not implemented by the number printer (only digits, sigfig and plus)", k)
    end
  end
  local digits, sigfig = key_number(keys, "digits"), key_number(keys, "sigfig")
  if digits and sigfig then fail("keys digits and sigfig cannot be used together") end
  if sigfig and sigfig < 1 then fail("key sigfig must be at least 1") end
  local cfg = read_config(config)

  if type(record) ~= "table" then
    fail("record is not a table (got %s)", record == nil and "nil" or type(record))
  end
  local kind = record.t
  if type(kind) ~= "string" then fail("record has no kind (member t)") end
  if kind ~= "float" and kind ~= "int" and kind ~= "decimal" then
    fail("record kind %s is not implemented by the number printer (only float, int and decimal)", kind)
  end
  local v = record.v
  if type(v) ~= "string" then fail("malformed %s record: v must be a string", kind) end
  local ok
  if kind == "int" then
    ok = v:match("^%-?0$") or v:match("^%-?[1-9][0-9]*$")
  else
    ok = plain_number(v)
  end
  if not ok then fail("malformed %s record: v = %q", kind, v) end

  local text, number, decimals, ip
  if kind == "float" then
    text, number, decimals, ip = print_float(v, class, digits, sigfig, cfg)
  else
    text, number, decimals, ip = print_exact(v, class, digits, sigfig, cfg)
  end
  -- `.plus` (N2 to N4): a number printed above zero takes "+" where the minus would stand
  if keys.plus == true and number > 0 then text = "+" .. text end
  -- `ip` is the whole part as printed, digits only, ungrouped and unsigned: for a suffix or a word that must
  -- not come from a double
  return text, {
    number = number,
    decimals = decimals,
    ip = ip,
    relation = "=",
    zero = number == 0,
    one = number == 1,
    two = number == 2,
  }
end

return M

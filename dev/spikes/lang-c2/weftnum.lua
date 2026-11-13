-- weftnum.lua: number printing on decimal strings (rule 1.4.13), for the (c) study.
-- A number is held as sign, a digit string D and an exponent e: value = D * 10^e.
-- Nothing here uses floating point to decide a digit, except is_whole(), which
-- copies R's test on the double.

local M = {}

M.cfg = { digits = 1, decimal_mark = ".", big_mark = ",", thousands_from = 1000, minus = "\u{2212}" }

-- "3.14159", "-1e-05", "1.5e+20" -> neg, D, e
function M.parse(s)
  s = s:gsub("%s", "")
  local neg = false
  if s:sub(1, 1) == "-" then neg = true; s = s:sub(2) elseif s:sub(1, 1) == "+" then s = s:sub(2) end
  local mant, ex = s:match("^([%d.]+)[eE]([-+]?%d+)$")
  if not mant then mant, ex = s, "0" end
  local ip, fp = mant:match("^(%d*)%.?(%d*)$")
  if not ip or (ip == "" and fp == "") then return nil end
  local D = (ip .. fp):gsub("^0+", "")
  local e = tonumber(ex) - #fp
  if D == "" then return false, "0", 0 end
  -- trailing zeros are kept: they do not change a rounding
  return neg, D, e
end

-- add one to a digit string
local function inc(D)
  local t, carry = {}, 1
  for i = #D, 1, -1 do
    local d = D:byte(i) - 48 + carry
    if d == 10 then t[i] = "0"; carry = 1 else t[i] = string.char(48 + d); carry = 0 end
  end
  return (carry == 1 and "1" or "") .. table.concat(t)
end

-- drop the last k digits of D, rounding half away from zero (on the magnitude)
local function drop(D, e, k)
  if k <= 0 then return D, e end
  if #D < k + 1 then D = string.rep("0", k + 1 - #D) .. D end
  local keep, nxt = D:sub(1, #D - k), D:byte(#D - k + 1) - 48
  if nxt >= 5 then keep = inc(keep) end
  keep = keep:gsub("^0+", "")
  if keep == "" then keep = "0" end
  return keep, e + k
end

-- to n significant digits
function M.round_sig(D, e, n)
  if D == "0" or #D <= n then return D, e end
  return drop(D, e, #D - n)
end

-- to nd decimal places (nd may be negative)
function M.round_places(D, e, nd)
  return drop(D, e, -nd - e)
end

local function lead(D, e) return #D + e - 1 end -- floor(log10(value)), value not zero

-- fixed notation with nd >= 0 decimals; returns the integer part and the fraction
local function fixed(D, e, nd)
  if e > 0 then D = D .. string.rep("0", e); e = 0 end
  if -e < nd then D = D .. string.rep("0", nd + e); e = -nd end
  -- now -e == nd (round_places was called first) or D is zero
  if D == "0" then return "0", string.rep("0", nd) end
  if #D <= nd then D = string.rep("0", nd - #D + 1) .. D end
  return D:sub(1, #D - nd), D:sub(#D - nd + 1)
end

local function group(int, mark)
  if mark == "" then return int end
  local out = int:reverse():gsub("(%d%d%d)", "%1" .. mark:reverse()):reverse()
  if out:sub(1, #mark) == mark then out = out:sub(#mark + 1) end
  return out
end

-- R's is_whole(): abs(v - round(v)) < 1e-9, on the double
local function is_whole_float(str)
  local x = tonumber(str)
  if not x then return false end
  if math.abs(x) >= 2 ^ 53 then return true end
  return math.abs(x - math.floor(x + 0.5)) < 1e-9
end

-- Print one number. `typ` is "int", "dec" (exact decimal) or "float" (a double,
-- given as its shortest round-trip text, read to 15 significant digits first).
-- opts: digits, sigfig. Returns text, a table {zero=, one=, two=, decimals=, neg=}.
function M.print_one(str, typ, opts, cfg)
  cfg = cfg or M.cfg
  opts = opts or {}
  local neg, D, e = M.parse(str)
  if neg == nil then return nil end
  if typ == "float" then D, e = M.round_sig(D, e, 15) end
  local nd
  if opts.sigfig then
    if D ~= "0" then
      D, e = M.round_places(D, e, opts.sigfig - 1 - lead(D, e))
    end
    nd = (D == "0") and (opts.sigfig - 1) or math.max(opts.sigfig - 1 - lead(D, e), 0)
    D, e = M.round_places(D, e, nd)
  elseif opts.digits then
    nd = opts.digits
    D, e = M.round_places(D, e, nd)
  else
    local whole
    if typ == "float" then whole = is_whole_float(str) else
      -- an exact number is whole when it has no fraction digit other than 0
      whole = e >= 0 or not D:sub(#D + e + 1):find("[1-9]")
      if e < 0 and #D <= -e then whole = (D == "0") end
    end
    nd = whole and 0 or cfg.digits
    D, e = M.round_places(D, e, nd)
  end
  local ip, fp = fixed(D, e, nd)
  local zero = not (ip .. fp):find("[1-9]")
  local shown = ip
  -- thousands marks from cfg.thousands_from up (compared as digit strings)
  local from = tostring(math.floor(cfg.thousands_from))
  if #ip > #from or (#ip == #from and ip >= from) then shown = group(ip, cfg.big_mark) end
  local txt = shown
  if nd > 0 then txt = txt .. cfg.decimal_mark .. fp end
  if neg and not zero then txt = cfg.minus .. txt end
  return txt, { zero = zero, one = (nd == 0 and ip == "1"), two = (nd == 0 and ip == "2"),
                decimals = nd > 0, neg = neg and not zero, int = ip, frac = fp }
end

-- ---- the double algorithm: a literal port of R's print_one() and round_half_away() ----
-- Same IEEE arithmetic and the same C printf as R, so it prints what R prints.

local function nearbyint(x)
  local f = math.floor(x)
  local d = x - f
  if d > 0.5 then return f + 1 elseif d < 0.5 then return f end
  return (f % 2 == 0) and f or f + 1
end

-- R's signif() (nmath/fprec.c), for a finite x > 0
local function signif(x, dig)
  if x == 0 then return 0 end
  local e10 = dig - 1 - math.floor(math.log(x, 10))
  if e10 > 0 then
    local p = 10.0 ^ e10
    return nearbyint(x * p) / p
  else
    local p = 10.0 ^ (-e10)
    return nearbyint(x / p) * p
  end
end

local function round_half_away(x, nd)
  if x == 0 then return 0 end
  local sgn, a = (x < 0) and -1 or 1, math.abs(x)
  local r
  if nd >= 0 then
    local y = a * 10.0 ^ nd
    if y == math.huge then return x end
    r = math.floor(signif(y, 15) + 0.5) / 10.0 ^ nd
  else
    local p = 10.0 ^ (-nd)
    r = math.floor(signif(a / p, 15) + 0.5) * p
  end
  return sgn * r
end

function M.print_double(str, opts, cfg)
  cfg = cfg or M.cfg
  opts = opts or {}
  local v = tonumber(str)
  if not v then return nil end
  local s, nd
  if opts.sigfig then
    s = (v == 0) and 0 or round_half_away(v, opts.sigfig - 1 - math.floor(math.log(math.abs(v), 10)))
    nd = (s == 0) and (opts.sigfig - 1) or math.max(opts.sigfig - 1 - math.floor(math.log(math.abs(s), 10)), 0)
  elseif opts.digits then
    nd = opts.digits
    s = round_half_away(v, nd)
  else
    nd = (math.abs(v - nearbyint(v)) < 1e-9) and 0 or cfg.digits
    s = round_half_away(v, nd)
  end
  nd = math.floor(nd)
  local txt = string.format("%." .. nd .. "f", math.abs(s))
  local num = tonumber(txt)
  local neg = s < 0 and num ~= 0
  local ip, fp = txt:match("^(%d+)%.?(%d*)$")
  local shown = ip
  if num >= cfg.thousands_from then shown = group(ip, cfg.big_mark) end
  local out = shown
  if nd > 0 then out = out .. cfg.decimal_mark .. fp end
  if neg then out = cfg.minus .. out end
  return out, { zero = (num == 0), one = (nd == 0 and ip == "1"), two = (nd == 0 and ip == "2"),
                decimals = nd > 0, neg = neg, int = ip, frac = fp }
end

-- compare two numbers given as strings; returns -1, 0, 1 (exact)
function M.compare(a, b)
  local na, Da, ea = M.parse(a)
  local nb, Db, eb = M.parse(b)
  if na == nil or nb == nil then return nil end
  if Da == "0" then na = false end
  if Db == "0" then nb = false end
  if na ~= nb then return na and -1 or 1 end
  local m = math.min(ea, eb)
  Da = Da .. string.rep("0", ea - m); Db = Db .. string.rep("0", eb - m)
  if Da == "0" and Db == "0" then return 0 end
  local c
  if #Da ~= #Db then c = (#Da < #Db) and -1 or 1
  elseif Da == Db then c = 0 else c = (Da < Db) and -1 or 1 end
  return na and -c or c
end

return M

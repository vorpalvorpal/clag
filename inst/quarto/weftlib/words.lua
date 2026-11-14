-- weftlib/words.lua: the English words of the filter (dev/design-6.md N100; rules 1.4.3 to 1.4.5,
-- 1.4.12, 1.4.15, 1.6.8): number words, ordinals, the default date, "a" and "an", capital letters,
-- and the collapse of a vector into text. A port of the helpers of R/format.R, as they are.
--
--   local words = dofile("weftlib/words.lua")
--
-- Every function is pure text: no Pandoc, no configuration global, no side effect on load. A function
-- that can refuse returns nil and the message; the caller says what kind of failure it is.

local M = {}

local ONES = { [0] = "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen" }
local TENS = { [2] = "twenty", [3] = "thirty", [4] = "forty", [5] = "fifty", [6] = "sixty", [7] = "seventy",
  [8] = "eighty", [9] = "ninety" }

-- spell_int(): a whole number below 1e9 in words, nil from there up (R's NA)
function M.spell_int(n)
  if n < 20 then return ONES[n] end
  if n < 100 then
    local t, o = n // 10, n % 10
    if o == 0 then return TENS[t] end
    return TENS[t] .. "-" .. ONES[o]
  end
  local function big(unit, name)
    local q, r = n // unit, n % unit
    local s = M.spell_int(q) .. " " .. name
    if r > 0 then s = s .. " " .. M.spell_int(r) end
    return s
  end
  if n < 1000 then return big(100, "hundred") end
  if n < 1e6 then return big(1000, "thousand") end
  if n < 1e9 then return big(1e6, "million") end
  return nil
end

-- the number in words, or `fallback` when it has none (R's spell_or())
function M.spell_or(n, fallback)
  if n ~= n or n < 0 or n ~= math.floor(n) then return fallback end
  local s = M.spell_int(math.tointeger(n) or n)
  if s == nil then return fallback end
  return s
end

-- the ordinal suffix of a whole number, from its printed digits (a string of digits: no double decides it);
-- a number is accepted and printed first
function M.ordinal_suffix(n)
  local ds = type(n) == "string" and n or string.format("%.0f", n)
  local last2 = math.tointeger(tonumber(ds:sub(math.max(#ds - 1, 1)))) or 0
  local last = last2 % 10
  if last2 >= 11 and last2 <= 13 then return "th"
  elseif last == 1 then return "st"
  elseif last == 2 then return "nd"
  elseif last == 3 then return "rd" end
  return "th"
end

M.MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December" }

M.DEFAULT_DATE_FORMAT = "%-d %B %Y"

M.WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

local DAYS_BEFORE = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
local SAKAMOTO = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }

-- an ISO date (YYYY-MM-DD) as a `date_format` string prints it: the tokens `%d %-d %e %m %-m %B %b %A %a
-- %Y %y %j %%` and literal text, as R's format_dates() reads them, in English. A port token by token with
-- no os.date, so no locale and no platform. Any other token is nil and a message (E20).
function M.date(iso, fmt)
  local ys, ms, ds = iso:match("^(%d+)%-(%d%d)%-(%d%d)$")
  if not ys then return nil, "`" .. iso .. "` is not a YYYY-MM-DD date." end
  local y, m, d = tonumber(ys), tonumber(ms), tonumber(ds)
  local yy = m < 3 and y - 1 or y
  local wday = (yy + yy // 4 - yy // 100 + yy // 400 + SAKAMOTO[m] + d) % 7      -- Sakamoto; 0 = Sunday
  local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
  local yday = DAYS_BEFORE[m] + d + ((leap and m > 2) and 1 or 0)
  local TOKENS = {
    ["%"] = "%",
    d = string.format("%02d", d), ["-d"] = tostring(d), e = string.format("%2d", d),
    m = string.format("%02d", m), ["-m"] = tostring(m),
    B = M.MONTHS[m], b = M.MONTHS[m]:sub(1, 3),
    A = M.WEEKDAYS[wday + 1], a = M.WEEKDAYS[wday + 1]:sub(1, 3),
    Y = ys, y = string.format("%02d", y % 100), j = string.format("%03d", yday),
  }
  local out, i, n = {}, 1, #fmt
  while i <= n do
    local c = fmt:sub(i, i)
    if c ~= "%" then
      out[#out + 1] = c
      i = i + 1
    else
      local tok = fmt:sub(i + 1, i + 1)
      if tok == "-" then tok = fmt:sub(i + 1, i + 2) end
      local text = TOKENS[tok]
      if not text then
        return nil, string.format("`date_format: %s` is not available in this version of weft.lua (rule 2.13.3).",
                                  tostring(fmt))
      end
      out[#out + 1] = text
      i = i + 1 + #tok
    end
  end
  return table.concat(out)
end

M.NUMBER_WORDS = {}
for w in ([[zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen
  sixteen seventeen eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand
  million billion]]):gmatch("[^ \t\r\n]+") do
  M.NUMBER_WORDS[w] = true
end

-- true when a printed number or number word opens with a vowel sound ("an 8", "an eleven"); nil and a
-- message when the text is neither (rule 1.4.5). Emphasis marks and a minus sign do not count.
function M.vowel_sound(text, minus, decimal_mark, big_mark)
  minus = minus or "\u{2212}"
  decimal_mark = decimal_mark or "."
  big_mark = big_mark or ","
  local orig = text
  text = text:gsub("^[*_~]+", "")
  for _, mk in ipairs({ minus, "-", "+" }) do
    if mk ~= "" and text:sub(1, #mk) == mk and text:sub(#mk + 1, #mk + 1):match("^[0-9]") then return false end
  end
  local bm = {}
  for _, cp in utf8.codes(big_mark) do bm[utf8.char(cp)] = true end
  local pos, n = 1, 0
  local run = {}
  for _, cp in utf8.codes(text) do
    local ch = utf8.char(cp)
    if ch:match("^[0-9]$") or (n > 0 and bm[ch] and ch ~= decimal_mark) then
      run[#run + 1] = ch
      n = n + 1
    else
      break
    end
  end
  if n > 0 then
    local d = table.concat(run):gsub("[^0-9]", "")
    local L = #d
    local k = (L % 3 == 0) and 3 or (L % 3)
    local g = tonumber(d:sub(1, k))
    if k == 1 then return g == 8 end
    if k == 2 then return g == 11 or g == 18 or (g >= 80 and g <= 89) end
    return g >= 800 and g <= 899
  end
  local w = text:match("^[A-Za-z]+")
  if w and M.NUMBER_WORDS[w:lower()] then
    local l = w:lower()
    return l == "eight" or l == "eleven" or l == "eighteen" or l == "eighty"
  end
  return nil, string.format("`.a` applies to numbers and number words only; \"%s\" is neither (rule 1.4.5).", orig)
end

-- Is this code point a letter, as R's [[:alnum:]] reads it in a UTF-8 locale? ASCII letters and digits,
-- the Latin letters of U+00C0 to U+024F (not the signs U+00D7 and U+00F7), Greek, Cyrillic and the
-- extended Latin of U+1E00 to U+1FFF. Punctuation, the minus and the dashes are not.
local function is_alnum(cp)
  if cp < 128 then
    return (cp >= 48 and cp <= 57) or (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122)
  end
  if cp == 0xD7 or cp == 0xF7 then return false end
  return (cp >= 0xC0 and cp <= 0x24F) or (cp >= 0x370 and cp <= 0x52F) or (cp >= 0x1E00 and cp <= 0x1FFF)
end

-- toupper() of one code point for the scripts above
local function upper_cp(cp)
  if cp >= 97 and cp <= 122 then return cp - 32 end
  if cp < 128 then return cp end
  if cp >= 0xE0 and cp <= 0xFE and cp ~= 0xF7 then return cp - 32 end
  if cp == 0xFF then return 0x178 end
  if (cp >= 0x100 and cp <= 0x137) or (cp >= 0x14A and cp <= 0x177) then
    return (cp % 2 == 1) and cp - 1 or cp
  end
  if (cp >= 0x139 and cp <= 0x148) or (cp >= 0x179 and cp <= 0x17E) then
    return (cp % 2 == 0) and cp - 1 or cp
  end
  if cp >= 0x3B1 and cp <= 0x3C9 then return (cp == 0x3C2) and 0x3A3 or cp - 32 end
  if cp >= 0x430 and cp <= 0x44F then return cp - 32 end
  if cp >= 0x450 and cp <= 0x45F then return cp - 80 end
  return cp
end

-- the text with its first letter or digit a capital (what comes before it is kept)
function M.capitalise(t)
  if t == "" then return t end
  local ok = pcall(utf8.len, t)
  if not ok or not utf8.len(t) then
    local lead = #t:match("^[^%w]*")
    if lead >= #t then return t end
    return t:sub(1, lead) .. t:sub(lead + 1, lead + 1):upper() .. t:sub(lead + 2)
  end
  for pos, cp in utf8.codes(t) do
    if is_alnum(cp) then
      return t:sub(1, pos - 1) .. utf8.char(upper_cp(cp)) .. t:sub(pos + #utf8.char(cp))
    end
  end
  return t
end

-- ---- collapse ----------------------------------------------------------------------------------------

-- The mark before the last joiner: the separator without its trailing spaces.
function M.serial_mark(sep) return (sep:gsub("[ \t]+$", "")) end

-- " and " becomes ", and ": a comma before the joiner, unless it has one.
function M.add_serial_comma(last, mark)
  if last:match("^ *,") then return last end
  return mark .. last
end

-- glue_vec(): the items joined; with two items only `last` is used
function M.glue(x, sep, last)
  local n = #x
  if n == 1 then return x[1] end
  if n == 2 then return x[1] .. last .. x[2] end
  return table.concat(x, sep, 1, n - 1) .. last .. x[n]
end

-- `.and`, `.or` and `.pairs` with `trunc`: the first `trunc` items, then "and N others"
function M.collapse_items(text, sep, last, trunc, serial)
  local n = #text
  if trunc and n > trunc then
    local rest = n - trunc
    return table.concat(text, sep, 1, trunc)
      .. ((serial and trunc >= 2) and M.serial_mark(sep) or "")
      .. " and " .. rest .. (rest == 1 and " other" or " others")
  end
  if serial and n >= 3 then last = M.add_serial_comma(last, M.serial_mark(sep)) end
  return M.glue(text, sep, last)
end

-- `.range`: text is {a, b}, number the printed numbers (or nil), raw the numbers as given (or nil), exact_gt
-- the order of the ends judged on their text (or nil).
-- Returns the text, or nil and a message.
-- `target` is "markdown" (or nil: today's text) or "tex": the ends are TeX texts and the joiner is always
-- `\ \text{to}\ `.
function M.collapse_range(text, number, raw, minus, exact_gt, plus, target)
  if #text ~= 2 then
    return nil, string.format("`.range` needs a value of length 2; this has %d (rule 5.3.2).", #text)
  end
  -- `exact_gt` (true or false) is the order of the two ends judged on the records' own text; the doubles
  -- decide only when it is nil
  local ord = (raw and raw[1] and raw[2]) and raw or number
  local above = exact_gt
  if above == nil then above = ord and ord[1] and ord[2] and ord[1] > ord[2] end
  if above then
    return nil, string.format("`.range` needs its first end not above its second; got %s and %s.", text[1], text[2])
  end
  if text[1] == text[2] then return text[1] end
  if target == "tex" then return text[1] .. "\\ \\text{to}\\ " .. text[2] end
  local neg = false
  for i = 1, 2 do
    if (number and number[i] and number[i] < 0) or (minus ~= "" and text[i]:sub(1, #minus) == minus)
       or (plus and text[i]:sub(1, 1) == "+") then neg = true end
  end
  return text[1] .. (neg and " to " or "\u{2013}") .. text[2]
end

-- `.ul`, `.ol` and `.dl` as markdown: a blank line before and after
function M.collapse_list(cls, text, nms)
  local parts = {}
  if cls == "ul" then
    for i, t in ipairs(text) do parts[i] = "- " .. t end
    return "\n" .. table.concat(parts, "\n") .. "\n"
  elseif cls == "ol" then
    for i, t in ipairs(text) do parts[i] = i .. ". " .. t end
    return "\n" .. table.concat(parts, "\n") .. "\n"
  end
  for i, t in ipairs(text) do parts[i] = nms[i] .. "\n:   " .. t end
  return "\n" .. table.concat(parts, "\n\n") .. "\n"
end

return M

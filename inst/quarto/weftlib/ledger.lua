-- weftlib/ledger.lua: the ledger the filter writes (dev/design-6.md N112; rules 7.1.1 to 7.1.5; the
-- entry layout of R/ledger.R, dev/design-2d.md D3 to D13), and the file hash of R/hashes.R.
--
--   local ledger = dofile("weftlib/ledger.lua")
--   h    = ledger.xxh3(bytes)             -- XXH3 64-bit, seed 0, 16 lower-case hex: what
--                                         -- cli::hash_raw_xxhash64() gives R
--   h    = ledger.file_hash(path)         -- the hash of the file with CR LF made LF, or nil
--   line = ledger.entry_line(e)           -- one entry, as R writes it, then "writer"
--   ok, err = ledger.write(opts)          -- merge into the ledger file (below)
--   text = ledger.sentence(text, s, e)    -- the sentence round text[s..e] (N112, not ICU)
--
-- ledger.write{ path, source, output, files = {{rel=, abs=}, ...}, entries = {...} } reads the file at
-- path when there is one, drops its lines whose writer is "filter", keeps the others byte for byte,
-- numbers each entry of the filter after the kept entries of the same key, sorts every line by 7.1.5
-- (file, section, kind, expression, occurrence; bytes, occurrence as a number), keeps the header it
-- found (adding to its `files` any file it lacks) or writes a new one, and replaces the file atomically.
--
-- An entry: file, section, kind, expr, id, context, text, arm, rel, raw, failed, sentence. Pure Lua 5.4,
-- no side effect on load.

local M = {}

-- ---- XXH3 64-bit, seed 0, default secret ---------------------------------------------------------------

local SECRET_HEX = "b8fe6c3923a44bbe7c01812cf721ad1cded46de9839097db7240a4a4b7b3671f"
  .. "cb79e64eccc0e578825ad07dccff7221b8084674f743248ee03590e6813a264c"
  .. "3c2852bb91c300cb88d0658b1b532ea371644897a20df94e3819ef46a9deacd8"
  .. "a8fa763fe39c343ff9dcbbc7c70b4f1d8a51e04bcdb45931c89f7ec9d9787364"
  .. "eac5ac8334d3ebc3c581a0fffa1363eb170ddd51b7f0da49d316552629d4689e"
  .. "2b16be587d47a1fc8ff8b8d17ad031ce45cb3a8f95160428afd7fbcabb4b407e"
local SECRET = (SECRET_HEX:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))

local P32_1, P32_2, P32_3 = 0x9E3779B1, 0x85EBCA77, 0xC2B2AE3D
local P64_1, P64_2, P64_3 = 0x9E3779B185EBCA87, 0xC2B2AE3D27D4EB4F, 0x165667B19E3779F9
local P64_4, P64_5 = 0x85EBCA77C2B2AE63, 0x27D4EB2F165667C5
local PMX1, PMX2 = 0x165667919E3779F9, 0x9FB21C651E98DF25

local unpack = string.unpack

local function r64(s, pos) return (unpack("<i8", s, pos + 1)) end  -- pos is 0-based
local function r32(s, pos) return (unpack("<I4", s, pos + 1)) end

local function rotl(x, n) return (x << n) | (x >> (64 - n)) end

local function swap64(x) return (unpack("<i8", string.pack(">i8", x))) end

-- the 128-bit product of two unsigned 64-bit numbers, low and high halves xor-ed
local function mul_fold(a, b)
  local a0, a1 = a & 0xFFFFFFFF, a >> 32
  local b0, b1 = b & 0xFFFFFFFF, b >> 32
  local p00, p01, p10, p11 = a0 * b0, a0 * b1, a1 * b0, a1 * b1
  local mid = (p00 >> 32) + (p01 & 0xFFFFFFFF) + (p10 & 0xFFFFFFFF)
  local lo = (mid << 32) | (p00 & 0xFFFFFFFF)
  local hi = p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32)
  return lo ~ hi
end

local function avalanche64(h)
  h = h ~ (h >> 33)
  h = h * P64_2
  h = h ~ (h >> 29)
  h = h * P64_3
  return h ~ (h >> 32)
end

local function avalanche3(h)
  h = h ~ (h >> 37)
  h = h * PMX1
  return h ~ (h >> 32)
end

local function rrmxmx(h, len)
  h = h ~ (rotl(h, 49) ~ rotl(h, 24))
  h = h * PMX2
  h = h ~ ((h >> 35) + len)
  h = h * PMX2
  return h ~ (h >> 28)
end

local function mix16(s, p, sp)
  local lo, hi = r64(s, p), r64(s, p + 8)
  return mul_fold(lo ~ r64(SECRET, sp), hi ~ r64(SECRET, sp + 8))
end

local function accumulate512(acc, s, p, sp)
  for i = 0, 7 do
    local v = r64(s, p + 8 * i)
    local k = v ~ r64(SECRET, sp + 8 * i)
    acc[(i ~ 1) + 1] = acc[(i ~ 1) + 1] + v
    acc[i + 1] = acc[i + 1] + (k & 0xFFFFFFFF) * (k >> 32)
  end
end

local function scramble(acc, sp)
  for i = 0, 7 do
    local a = acc[i + 1]
    a = a ~ (a >> 47)
    a = a ~ r64(SECRET, sp + 8 * i)
    acc[i + 1] = a * P32_1
  end
end

local function long_hash(s, len)
  local acc = { P32_3, P64_1, P64_2, P64_3, P64_4, P32_2, P64_5, P32_1 }
  local per_block = 16            -- (192 - 64) / 8 stripes
  local block_len = 64 * per_block
  local nb_blocks = (len - 1) // block_len
  for n = 0, nb_blocks - 1 do
    for st = 0, per_block - 1 do accumulate512(acc, s, n * block_len + st * 64, st * 8) end
    scramble(acc, 192 - 64)
  end
  local nb_stripes = ((len - 1) - block_len * nb_blocks) // 64
  for st = 0, nb_stripes - 1 do accumulate512(acc, s, nb_blocks * block_len + st * 64, st * 8) end
  accumulate512(acc, s, len - 64, 192 - 64 - 7)
  local result = len * P64_1
  for i = 0, 3 do
    result = result + mul_fold(acc[2 * i + 1] ~ r64(SECRET, 11 + 16 * i), acc[2 * i + 2] ~ r64(SECRET, 11 + 16 * i + 8))
  end
  return avalanche3(result)
end

function M.xxh3(s)
  local len = #s
  local h
  if len == 0 then
    h = avalanche64(r64(SECRET, 56) ~ r64(SECRET, 64))
  elseif len <= 3 then
    local c1, c2, c3 = s:byte(1), s:byte(((len >> 1) + 1)), s:byte(len)
    local combined = (c1 << 16) | (c2 << 24) | c3 | (len << 8)
    h = avalanche64(combined ~ (r32(SECRET, 0) ~ r32(SECRET, 4)))
  elseif len <= 8 then
    local in1, in2 = r32(s, 0), r32(s, len - 4)
    local bitflip = r64(SECRET, 8) ~ r64(SECRET, 16)
    h = rrmxmx(((in1 << 32) + in2) ~ bitflip, len)
  elseif len <= 16 then
    local f1 = r64(SECRET, 24) ~ r64(SECRET, 32)
    local f2 = r64(SECRET, 40) ~ r64(SECRET, 48)
    local lo = r64(s, 0) ~ f1
    local hi = r64(s, len - 8) ~ f2
    h = avalanche3(len + swap64(lo) + hi + mul_fold(lo, hi))
  elseif len <= 128 then
    local acc = len * P64_1
    if len > 32 then
      if len > 64 then
        if len > 96 then
          acc = acc + mix16(s, 48, 96) + mix16(s, len - 64, 112)
        end
        acc = acc + mix16(s, 32, 64) + mix16(s, len - 48, 80)
      end
      acc = acc + mix16(s, 16, 32) + mix16(s, len - 32, 48)
    end
    acc = acc + mix16(s, 0, 0) + mix16(s, len - 16, 16)
    h = avalanche3(acc)
  elseif len <= 240 then
    local acc = len * P64_1
    for i = 0, 7 do acc = acc + mix16(s, 16 * i, 16 * i) end
    acc = avalanche3(acc)
    for i = 8, len // 16 - 1 do acc = acc + mix16(s, 16 * i, 16 * (i - 8) + 3) end
    acc = acc + mix16(s, len - 16, 136 - 17)
    h = avalanche3(acc)
  else
    h = long_hash(s, len)
  end
  return string.format("%016x", h)
end

-- the hash of a file's bytes with every CR LF made LF (R/hashes.R: file_hash()), or nil
function M.file_hash(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local b = f:read("a")
  f:close()
  if not b then return nil end
  return M.xxh3((b:gsub("\r\n", "\n")))
end

-- ---- JSON text as R writes it (R/ledger.R: json_str, json_num) ------------------------------------------

local INVISIBLE = { [0x85] = true, [0xa0] = true, [0xad] = true, [0x61c] = true, [0x2028] = true,
                    [0x2029] = true, [0x202a] = true, [0x202b] = true, [0x202c] = true, [0x202d] = true,
                    [0x202e] = true, [0x202f] = true, [0x205f] = true, [0x2060] = true, [0xfeff] = true }
for cp = 0x2000, 0x200f do INVISIBLE[cp] = true end
for cp = 0x2066, 0x2069 do INVISIBLE[cp] = true end

local function json_str(x)
  x = tostring(x)
  local out = {}
  local ok = pcall(function()
    for _, cp in utf8.codes(x) do
      if cp == 34 then out[#out + 1] = '\\"'
      elseif cp == 92 then out[#out + 1] = "\\\\"
      elseif cp == 10 then out[#out + 1] = "\\n"
      elseif cp == 9 then out[#out + 1] = "\\t"
      elseif cp == 13 then out[#out + 1] = "\\r"
      elseif cp < 32 or INVISIBLE[cp] then out[#out + 1] = string.format("\\u%04x", cp)
      else out[#out + 1] = utf8.char(cp) end
    end
  end)
  if not ok then return '"\u{fffd}"' end
  return '"' .. table.concat(out) .. '"'
end
M.json_str = json_str

local function json_nul(x, f)
  if x == nil then return "null" end
  return f(x)
end

local function json_num(x)
  if x == 0 then return "0" end
  return (string.format("%.6g", x):gsub("^[ \t\r\n]+", ""))
end

function M.entry_line(e)
  return table.concat({
    '{"file":', json_str(e.file),
    ',"section":', json_str(e.section or ""),
    ',"kind":', json_str(e.kind),
    ',"expr":', json_str(e.expr),
    ',"occ":', string.format("%d", e.occ),
    ',"id":', json_nul(e.id, json_str),
    ',"context":', json_str(e.context or "prose"),
    ',"text":', json_nul(e.text, json_str),
    ',"arm":', json_nul(e.arm, json_str),
    ',"rel":', json_nul(e.rel, json_str),
    ',"raw":', json_nul(e.raw, json_num),
    ',"unit":null',
    ',"failed":', json_nul(e.failed, json_str),
    ',"dict":[]',
    ',"sentence":', json_str(e.sentence or ""),
    ',"writer":"filter"}',
  })
end

-- ---- the sentence (N112) ---------------------------------------------------------------------------------

-- The text of a block (white space already made one space) cut at the last ". ", "? " or "! " that ends
-- before byte s, and at the first one after byte e.
function M.sentence(text, s, e)
  local start = 1
  for _, mark in ipairs({ ". ", "? ", "! " }) do
    local pos = 1
    while true do
      local a = text:find(mark, pos, true)
      if not a or a + 1 >= s then break end
      if a + 2 > start then start = a + 2 end
      pos = a + 1
    end
  end
  local stop = #text
  for _, mark in ipairs({ ". ", "? ", "! " }) do
    local a = text:find(mark, e + 1, true)
    if a and a < stop then stop = a end
  end
  return (text:sub(start, stop):gsub("^ ", ""):gsub(" $", ""))
end

-- ---- merge and write ------------------------------------------------------------------------------------

local function read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

local function lines_of(text)
  local out = {}
  for l in (text .. "\n"):gmatch("(.-)\r?\n") do out[#out + 1] = l end
  while #out > 0 and out[#out] == "" do out[#out] = nil end
  return out
end

-- Replace a file atomically: a temporary file beside it, then a rename.
function M.write_file(path, text)
  local tmp = path .. ".weft-tmp"
  local f, err = io.open(tmp, "wb")
  if not f then return false, err end
  f:write(text)
  f:close()
  local ok, rerr = os.rename(tmp, path)
  if not ok then
    os.remove(path)
    ok, rerr = os.rename(tmp, path)
    if not ok then os.remove(tmp); return false, rerr end
  end
  return true
end

function M.make_dirs(dir)
  local ok, err = pcall(pandoc.system.make_directory, dir, true)
  return ok, err
end

-- the entries of a header's `files` object: names and hashes in file order, and where the object sits
local function header_files(line)
  local s = line:find('"files":{', 1, true)
  if not s then return nil end
  local i = s + #'"files":{'
  local items = {}
  while true do
    local c = line:sub(i, i)
    if c == "}" then return items, s, i end
    if c == "," then i = i + 1
    elseif c == '"' then
      local j = i + 1
      while j <= #line do
        local d = line:sub(j, j)
        if d == "\\" then j = j + 2 elseif d == '"' then break else j = j + 1 end
      end
      local key = line:sub(i, j)
      local after = line:match("^:(null)", j + 1) or line:match('^:("[^"]*")', j + 1)
      if not after then return nil end
      items[#items + 1] = { key = key, value = after }
      i = j + 1 + 1 + #after
    else
      return nil
    end
  end
end

local function sorted_files_text(items)
  table.sort(items, function(a, b) return a.key < b.key end)
  local parts = {}
  for _, it in ipairs(items) do parts[#parts + 1] = it.key .. ":" .. it.value end
  return '"files":{' .. table.concat(parts, ",") .. "}"
end

local function new_header(source, output, files)
  local items = {}
  for _, f in ipairs(files) do
    local h = M.file_hash(f.abs)
    items[#items + 1] = { key = json_str(f.rel), value = h and ('"' .. h .. '"') or "null" }
  end
  return string.format('{"weft":"ledger","version":1,"source":%s,"output":%s,"dict":{},%s,"targets":{}}',
                       json_str(source), json_str(output), sorted_files_text(items))
end

local function decode(line)
  local ok, d = pcall(pandoc.json.decode, line, false)
  if ok and type(d) == "table" and getmetatable(d) == nil then return d end
  return nil
end

local function key_of(d)
  return table.concat({ d.file or "", d.section or "", d.kind or "", d.expr or "" }, "\0")
end

function M.write(o)
  local old = read_all(o.path)
  local header, kept = nil, {}
  if old then
    for i, l in ipairs(lines_of(old)) do
      if l:find("^[ \t\r\n]*$") then
        -- skipped
      elseif i == 1 and l:find('^{"weft":"ledger"') then
        local d = decode(l)
        local v = d and tonumber(d.version) or 1
        if v <= 1 then header = l end
      else
        local d = decode(l)
        if d and d.weft == nil and d.writer ~= "filter" then
          kept[#kept + 1] = { line = l, file = d.file or "", section = d.section or "", kind = d.kind or "",
                              expr = d.expr or "", occ = tonumber(d.occ) or 0, n = #kept }
        end
      end
    end
  end
  -- numbering: the filter's entries follow the kept entries of the same key
  local base, counts = {}, {}
  for _, k in ipairs(kept) do
    local key = table.concat({ k.file, k.section, k.kind, k.expr }, "\0")
    if (base[key] or 0) < k.occ then base[key] = k.occ end
  end
  local all = {}
  for _, k in ipairs(kept) do all[#all + 1] = k end
  for _, e in ipairs(o.entries) do
    local key = key_of(e)
    counts[key] = (counts[key] or 0) + 1
    e.occ = (base[key] or 0) + counts[key]
    all[#all + 1] = { line = M.entry_line(e), file = e.file, section = e.section or "", kind = e.kind,
                      expr = e.expr, occ = e.occ, n = #all }
  end
  table.sort(all, function(a, b)
    if a.file ~= b.file then return a.file < b.file end
    if a.section ~= b.section then return a.section < b.section end
    if a.kind ~= b.kind then return a.kind < b.kind end
    if a.expr ~= b.expr then return a.expr < b.expr end
    if a.occ ~= b.occ then return a.occ < b.occ end
    return a.n < b.n
  end)
  -- the header: the one found, with any file it lacks added; or a new one
  if header then
    local items, s, e = header_files(header)
    if items then
      local have, added = {}, false
      for _, it in ipairs(items) do have[it.key] = true end
      for _, f in ipairs(o.files) do
        local key = json_str(f.rel)
        if not have[key] then
          local h = M.file_hash(f.abs)
          items[#items + 1] = { key = key, value = h and ('"' .. h .. '"') or "null" }
          have[key] = true
          added = true
        end
      end
      if added then header = header:sub(1, s - 1) .. sorted_files_text(items) .. header:sub(e + 1) end
    end
  else
    header = new_header(o.source, o.output, o.files)
  end
  local out = { header }
  for _, a in ipairs(all) do out[#out + 1] = a.line end
  return M.write_file(o.path, table.concat(out, "\n") .. "\n")
end

return M

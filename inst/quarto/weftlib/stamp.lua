-- weftlib/stamp.lua: the stamp the filter writes (dev/design-6.md N110, N111; R/collect.R: record_knit,
-- stamp_file_name).
--
--   local stamp = dofile("weftlib/stamp.lua")
--   name = stamp.file_name("ch/a.qmd")          -- "ch__a.qmd.json", as R's stamp_file_name()
--   old  = stamp.read(path)                     -- the parsed stamp, or nil
--   ok, err = stamp.write(path, s)              -- s: source, run, executed, checks, failures (lines),
--                                               --    writers (array), named, fresh (true, false or nil)
--   line = stamp.failure_line(t)                -- a decoded failure again as one line, in R's order
--
-- The members are R's, in R's order, then writers, named and fresh. Writes are atomic. Pure Lua 5.4, no
-- side effect on load.

local M = {}

local function json_str(s)
  if s == nil or s == pandoc.json.null then return "null" end
  s = tostring(s)
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

local function json_int(x)
  if x == nil or x == pandoc.json.null then return "null" end
  local i = math.tointeger(tonumber(x))
  if i == nil then return "null" end
  return string.format("%d", i)
end

-- R's stamp_file_name(): a path's folders joined by `__`; a segment's `%`, `__` and a leading or trailing
-- `_` escaped
function M.file_name(rel)
  local segs = {}
  for seg in (rel:gsub("\\", "/") .. "/"):gmatch("(.-)/") do
    seg = seg:gsub("%%", "%%25")
    seg = seg:gsub("__", "_%%5F")
    seg = seg:gsub("__", "_%%5F")
    seg = seg:gsub("^_", "%%5F")
    seg = seg:gsub("_$", "%%5F")
    segs[#segs + 1] = seg
  end
  return table.concat(segs, "__") .. ".json"
end

function M.read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  local ok, d = pcall(pandoc.json.decode, text, false)
  if ok and type(d) == "table" and getmetatable(d) == nil then return d end
  return nil
end

-- a failure as the hooks write it (R/collect.R: failure_json), from its decoded form
function M.failure_line(t)
  local parts = { '"source":' .. json_str(t.source or "knit") }
  if t.level ~= nil and t.level ~= pandoc.json.null then parts[#parts + 1] = '"level":' .. json_str(t.level) end
  parts[#parts + 1] = '"kind":' .. json_str(t.kind)
  parts[#parts + 1] = '"file":' .. json_str(t.file)
  parts[#parts + 1] = '"line":' .. json_int(t.line)
  parts[#parts + 1] = '"chunk":' .. json_str(t.chunk)
  parts[#parts + 1] = '"expr":' .. json_str(t.expr)
  parts[#parts + 1] = '"detail":' .. json_str(t.detail)
  parts[#parts + 1] = '"hint":' .. json_str(t.hint)
  parts[#parts + 1] = '"option":' .. json_str(t.option)
  parts[#parts + 1] = '"chunk_line":' .. json_int(t.chunk_line)
  return "{" .. table.concat(parts, ",") .. "}"
end

function M.text(s)
  local out = {
    "{",
    "  \"source\": " .. json_str(s.source) .. ",",
    "  \"run\": " .. json_str(s.run) .. ",",
    "  \"executed\": " .. json_str(s.executed) .. ",",
    "  \"checks\": " .. json_int(s.checks) .. ",",
  }
  if #s.failures == 0 then
    out[#out + 1] = "  \"failures\": [],"
  else
    out[#out + 1] = "  \"failures\": ["
    for i, l in ipairs(s.failures) do out[#out + 1] = "    " .. l .. (i < #s.failures and "," or "") end
    out[#out + 1] = "  ],"
  end
  local w = {}
  for _, x in ipairs(s.writers) do w[#w + 1] = json_str(x) end
  out[#out + 1] = "  \"writers\": [" .. table.concat(w, ", ") .. "],"
  out[#out + 1] = "  \"named\": " .. json_int(s.named) .. ","
  out[#out + 1] = "  \"fresh\": " .. (s.fresh == nil and "null" or tostring(s.fresh))
  out[#out + 1] = "}"
  return table.concat(out, "\n") .. "\n"
end

function M.write(path, s)
  local tmp = path .. ".weft-tmp"
  local f, err = io.open(tmp, "wb")
  if not f then return false, err end
  f:write(M.text(s))
  f:close()
  local ok, rerr = os.rename(tmp, path)
  if not ok then
    os.remove(path)
    ok, rerr = os.rename(tmp, path)
    if not ok then os.remove(tmp); return false, rerr end
  end
  return true
end

return M

-- weftlib/report.lua: failures, the one report, collection lines and the exit rule
-- (dev/design-6.md N86, N88, N111; rules 2.6.2, 2.6.6, 9.4.1).
--
--   local report = dofile("weftlib/report.lua")
--   text = report.build(fails, warned)      -- the report, in the layout of weft-post-render.R
--   line = report.json_line(f, level)       -- one collection line (source "resolve")
--   path = report.collect_path(find_upward) -- the open collection file, or nil
--
-- A failure is {kind, file, line, chunk, expr, detail, hint}: detail and hint may hold several
-- lines. fails and warned are arrays in the order found. No side effect on load.

local M = {}

local function where(f)
  local file = f.file or "<unknown>"
  if f.line then return string.format("%s:%d", file, f.line) end
  if f.chunk then return string.format("%s chunk %s", file, f.chunk) end
  return file
end

local function entry(f, tag)
  local head = string.format("  %s  %s%s", where(f), tag and ("[" .. f.kind .. "] ") or "", f.expr or "")
  local out = { (head:gsub("%s+$", "")) }
  for _, field in ipairs({ f.detail, f.hint }) do
    if field and field ~= "" then
      for l in (field .. "\n"):gmatch("(.-)\n") do out[#out + 1] = "      " .. l end
    end
  end
  return out
end

local function plural(n, one, many) return n == 1 and one or many end

function M.build(fails, warned)
  local claims, other = {}, {}
  for _, f in ipairs(fails) do
    if f.kind == "failed claim" then claims[#claims + 1] = f else other[#other + 1] = f end
  end
  local out = {}
  local function add(lines) for _, l in ipairs(lines) do out[#out + 1] = l end end
  if #claims > 0 then
    out[#out + 1] = string.format("weft: %d %s failed", #claims, plural(#claims, "claim", "claims"))
    for _, f in ipairs(claims) do add(entry(f, false)) end
    out[#out + 1] = "Read each sentence. If FALSE is right, rewrite the sentence."
    out[#out + 1] = "Do not loosen a claim to clear this."
  end
  if #other > 0 then
    out[#out + 1] = string.format("weft: %d %s", #other, plural(#other, "failure", "failures"))
    for _, f in ipairs(other) do add(entry(f, true)) end
  end
  if #warned > 0 then
    out[#out + 1] = string.format("weft: %d warned check(s)", #warned)
    for _, f in ipairs(warned) do add(entry(f, f.kind ~= "failed claim")) end
  end
  if #out == 0 then return "" end
  return table.concat(out, "\n") .. "\n"
end

-- ---- collection lines ----------------------------------------------------------------------------

local function json_str(s)
  if s == nil then return "null" end
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
M.json_str = json_str

function M.json_line(f, level)
  local parts = { '"source":"resolve"' }
  if level then parts[#parts + 1] = '"level":' .. json_str(level) end
  parts[#parts + 1] = '"kind":' .. json_str(f.kind)
  parts[#parts + 1] = '"file":' .. json_str(f.file)
  parts[#parts + 1] = '"line":' .. (f.line and string.format("%d", f.line) or "null")
  parts[#parts + 1] = '"chunk":' .. json_str(f.chunk)
  parts[#parts + 1] = '"expr":' .. json_str(f.expr)
  parts[#parts + 1] = '"detail":' .. json_str(f.detail)
  parts[#parts + 1] = '"hint":' .. json_str(f.hint)
  parts[#parts + 1] = '"option":null'
  parts[#parts + 1] = '"chunk_line":null'
  return "{" .. table.concat(parts, ",") .. "}"
end

-- The open collection file of this render: WEFT_COLLECT, or (inside Quarto only) the
-- .weft/failures.jsonl of the project when it names the current run (2.6.6). find_upward(rel)
-- returns an open file handle and its path, or nil.
function M.collect_path(find_upward, in_quarto)
  local p = os.getenv("WEFT_COLLECT")
  if p and p ~= "" then return p end
  if not in_quarto then return nil end
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

function M.truthy(v)
  if v == nil then return false end
  v = tostring(v):gsub("^[\"']", ""):gsub("[\"']$", ""):lower()
  return v == "1" or v == "true"
end

return M

-- weftlib/config.lua: the filter's configuration (dev/design-6.md N84, D18, E33).
--
--   local config = dofile("weftlib/config.lua")
--   cfg, problems = config.load(source_path, source_text)
--
-- Reads `_weft.yml` (found upward from the source's folder, at most 8 levels) and the `weft:`
-- mapping of the source's own front matter, as text, with a flat reader and never through
-- Pandoc's metadata (which mangles " " and "--", measured 10). The document's value wins.
--   cfg       the settings (defaults filled in), plus cfg.formatters, a set of the class names (no
--             dot) under a non-empty `formatters:` mapping.
--   problems  an array of {file = <display path>, key = <key>, value = <text>, what = <kind>}:
--             a value of the wrong kind for its key (E33); the default is used for it.
-- No side effect on load.

local M = {}

M.DEFAULTS = {
  digits = 1, decimal_mark = ".", big_mark = ",", thousands_from = 1000, minus = "\u{2212}",
  governor_class = "num", pct_proportion = true, serial_comma = false, count_threshold = 10,
  word_limit = 100, date_format = "%-d %B %Y", draft = false, ledger = false,
}

local KINDS = {
  digits = "int", thousands_from = "int", count_threshold = "int", word_limit = "int",
  pct_proportion = "bool", serial_comma = "bool", draft = "bool", ledger = "bool",
  decimal_mark = "str", big_mark = "str", minus = "str", governor_class = "str", date_format = "str",
}
local WHAT = { int = "whole number", bool = "true or false", str = "string" }

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- one VALUE: returns kind ("str", "bool", "int", "bare", "empty", "bad") and the value
local function scalar(text)
  text = trim(text)
  if text == "" or text:sub(1, 1) == "#" then return "empty" end
  local q = text:sub(1, 1)
  if q == '"' then
    local i = 2
    while i <= #text do
      local c = text:sub(i, i)
      if c == "\\" then i = i + 2
      elseif c == '"' then break
      else i = i + 1 end
    end
    if i > #text then return "bad", text end
    local ok, v = pcall(pandoc.json.decode, text:sub(1, i), false)
    if ok and type(v) == "string" then return "str", v end
    return "bad", text
  elseif q == "'" then
    local out, i = {}, 2
    while i <= #text do
      local c = text:sub(i, i)
      if c == "'" then
        if text:sub(i + 1, i + 1) == "'" then out[#out + 1] = "'"; i = i + 2
        else return "str", table.concat(out) end
      else out[#out + 1] = c; i = i + 1 end
    end
    return "bad", text
  end
  -- a bare value: a trailing `# comment` (a # after white space) is removed
  local body = text:gsub("%s+#.*$", "")
  body = trim(body)
  if body == "true" then return "bool", true end
  if body == "false" then return "bool", false end
  if body:match("^%d+$") then return "int", math.tointeger(tonumber(body)) or tonumber(body), body end
  return "bare", body
end

-- the lines of a block at exactly `indent`: calls set(key, rest_of_line) for each `KEY: VALUE`
-- line; deeper lines (the nested keys of other settings) are skipped
local function read_block(lines, indent, set)
  for _, line in ipairs(lines) do
    local ind, key, rest = line:match("^(%s*)([%w_%.%-]+):(.*)$")
    if ind and #ind == indent then set(key, rest) end
  end
end

local function apply(cfg, problems, file, key, rest)
  local want = KINDS[key]
  if not want then return end
  local kind, v = scalar(rest)
  local ok = false
  if want == "int" then ok = kind == "int"
  elseif want == "bool" then ok = kind == "bool"
  else ok = kind == "str" or kind == "bare" or kind == "int" or kind == "bool" end
  if ok and want == "str" and (kind == "int" or kind == "bool") then
    v = trim((rest:gsub("%s+#.*$", "")))
  end
  if not ok then
    problems[#problems + 1] = { file = file, key = key, value = trim((rest:gsub("%s+#.*$", ""))), what = WHAT[want] }
  else
    cfg[key] = v
  end
end

local function front_matter_weft(text)
  local lines = {}
  for l in (text .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = l end
  if not lines[1] or not lines[1]:match("^%-%-%-%s*$") then return nil end
  local stop
  for i = 2, #lines do
    if lines[i]:match("^%-%-%-%s*$") or lines[i]:match("^%.%.%.%s*$") then stop = i; break end
  end
  if not stop then return nil end
  local out, inside = {}, false
  for i = 2, stop - 1 do
    local l = lines[i]
    if l:match("^weft:%s*$") or l:match("^weft:%s*#") then inside = true
    elseif inside then
      if l:match("^%s*$") or l:match("^%s*#") then
        -- skip
      elseif l:match("^%s") then out[#out + 1] = l
      else inside = false end
    end
  end
  if #out == 0 then return {} end
  -- the first indent level found is the one read
  local ind = #out[1]:match("^(%s*)")
  for _, l in ipairs(out) do
    local n = #l:match("^(%s*)")
    if n < ind then ind = n end
  end
  return out, ind
end

local function lines_of(text)
  local lines = {}
  for l in (text .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = l end
  return lines
end

local function read_formatters(lines, indent, formatters)
  local on = false
  local first
  for _, l in ipairs(lines) do
    local ind, key = l:match("^(%s*)([^%s:#][^:]*):")
    if l:match("^%s*$") or l:match("^%s*#") then
      -- skip
    elseif #(l:match("^(%s*)")) == indent and l:match("^%s*formatters:") then
      on = true
      first = nil
    elseif on then
      local n = #(l:match("^(%s*)"))
      if n <= indent then on = false
      elseif ind and (first == nil or n == first) then
        first = n
        formatters[(key:gsub("^%.", ""))] = true
      end
    end
  end
end

function M.read_text(text, indent, file, cfg, problems)
  local lines = lines_of(text)
  read_block(lines, indent, function(key, rest) apply(cfg, problems, file, key, rest) end)
  read_formatters(lines, indent, cfg.formatters)
end

local function dir_of(path)
  return (path:gsub("[/\\]+[^/\\]*$", ""))
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

-- find a file by name in a folder or a parent of it (at most 8 levels)
function M.find_upward(start_dir, rel)
  local cur = start_dir
  for _ = 1, 8 do
    local p = cur .. "/" .. rel
    local f = io.open(p, "r")
    if f then f:close(); return p end
    local parent = dir_of(cur)
    if parent == cur or parent == "" then break end
    cur = parent
  end
  return nil
end

-- source_path: the document's path, or nil; source_text: its text, or nil; cwd: the working folder
function M.load(source_path, source_text, cwd)
  local cfg = {}
  for k, v in pairs(M.DEFAULTS) do cfg[k] = v end
  cfg.formatters = {}
  local problems = {}
  local function display(p)
    if cwd and p:sub(1, #cwd + 1) == cwd .. "/" then return p:sub(#cwd + 2) end
    return (p:gsub("^%./", ""))
  end
  local start = cwd or "."
  if source_path then
    local d = dir_of(source_path)
    if d == source_path then d = "." end
    if d:sub(1, 1) == "/" or d:match("^%a:[/\\]") or not cwd then start = d
    else start = (cwd .. "/" .. d):gsub("/%./", "/"):gsub("/%.$", "") end
  end
  local yml = M.find_upward(start, "_weft.yml")
  if yml then
    local text = read_file(yml)
    if text then M.read_text(text, 0, display(yml), cfg, problems) end
  end
  if source_text then
    local out, indent = front_matter_weft(source_text)
    if out and #out > 0 then
      M.read_text(table.concat(out, "\n"), indent, source_path and display(source_path) or "the document", cfg, problems)
    end
  end
  return cfg, problems
end

return M
